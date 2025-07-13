terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  # Increase timeouts for large layer uploads
  default_tags {
    tags = {
      Project = var.project_name
    }
  }
}

# Local values for cross-platform compatibility
locals {
  # Simple platform detection using path separator
  is_windows = substr(replace(path.cwd, "/", ""), 1, 1) == ":"
}

# S3 Bucket for document uploads
resource "aws_s3_bucket" "document_bucket" {
  bucket = "${var.project_name}-documents-${random_string.bucket_suffix.result}"
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_versioning" "document_bucket_versioning" {
  bucket = aws_s3_bucket.document_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Removed S3 bucket notification - using DynamoDB Streams instead

# DynamoDB Table for results
resource "aws_dynamodb_table" "document_results" {
  name           = "${var.project_name}-results"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "document_id"

  # Enable DynamoDB Streams to trigger Step Function
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "document_id"
    type = "S"
  }

  attribute {
    name = "processed_date"
    type = "S"
  }

  global_secondary_index {
    name               = "ProcessedDateIndex"
    hash_key           = "processed_date"
    projection_type    = "ALL"
  }

  tags = {
    Name        = "${var.project_name}-results"
    Environment = var.environment
  }
}

# IAM Role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.document_bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.document_results.arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeStream",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:ListStreams"
        ]
        Resource = aws_dynamodb_table.document_results.stream_arn
      },
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = aws_sfn_state_machine.document_processor.arn
      }
    ]
  })
}

# IAM Role for Step Functions
resource "aws_iam_role" "step_function_role" {
  name = "${var.project_name}-step-function-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "step_function_policy" {
  name = "${var.project_name}-step-function-policy"
  role = aws_iam_role.step_function_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.qr_scanner.arn,
          aws_lambda_function.ocr_text.arn,
          aws_lambda_function.validator.arn
        ]
      }
    ]
  })
}

# Lambda Layers - Let Terraform handle the building
data "archive_file" "common_layer" {
  type        = "zip"
  source_dir  = "${path.module}/../layers/common/python"
  output_path = "${path.module}/../.build/layers/common.zip"
}

resource "aws_lambda_layer_version" "common" {
  filename            = data.archive_file.common_layer.output_path
  layer_name          = "${var.project_name}-common-layer"
  compatible_runtimes = ["python3.12"]
  source_code_hash    = data.archive_file.common_layer.output_base64sha256
}


# OCR Layer with dependencies
resource "null_resource" "install_ocr_deps" {
  triggers = {
    requirements = filemd5("${path.module}/../layers/ocr/requirements.txt")
  }
  
  provisioner "local-exec" {
    command = local.is_windows ? "powershell.exe -Command \"if (!(Test-Path '${path.module}/../.build/layers/ocr_deps')) { New-Item -ItemType Directory -Path '${path.module}/../.build/layers/ocr_deps' -Force }; pip install -r '${path.module}/../layers/ocr/requirements.txt' -t '${path.module}/../.build/layers/ocr_deps'\"" : "mkdir -p '${path.module}/../.build/layers/ocr_deps' && pip3 install -r '${path.module}/../layers/ocr/requirements.txt' -t '${path.module}/../.build/layers/ocr_deps'"
  }
}

data "archive_file" "ocr_layer" {
  type        = "zip"
  source_dir  = "${path.module}/../.build/layers/ocr_deps"
  output_path = "${path.module}/../.build/layers/ocr.zip"
  
  depends_on = [null_resource.install_ocr_deps]
}

resource "aws_lambda_layer_version" "ocr" {
  filename            = data.archive_file.ocr_layer.output_path
  layer_name          = "${var.project_name}-ocr-layer"
  compatible_runtimes = ["python3.12"]
  source_code_hash    = data.archive_file.ocr_layer.output_base64sha256
}

# QR Layer with dependencies
resource "null_resource" "install_qr_deps" {
  triggers = {
    requirements = filemd5("${path.module}/../layers/qr/requirements.txt")
  }
  
  provisioner "local-exec" {
    command = local.is_windows ? "powershell.exe -Command \"if (!(Test-Path '${path.module}/../.build/layers/qr_deps')) { New-Item -ItemType Directory -Path '${path.module}/../.build/layers/qr_deps' -Force }; pip install -r '${path.module}/../layers/qr/requirements.txt' -t '${path.module}/../.build/layers/qr_deps'\"" : "mkdir -p '${path.module}/../.build/layers/qr_deps' && pip3 install -r '${path.module}/../layers/qr/requirements.txt' -t '${path.module}/../.build/layers/qr_deps'"
  }
}

data "archive_file" "qr_layer" {
  type        = "zip"
  source_dir  = "${path.module}/../.build/layers/qr_deps"
  output_path = "${path.module}/../.build/layers/qr.zip"
  
  depends_on = [null_resource.install_qr_deps]
}

resource "aws_lambda_layer_version" "qr" {
  filename            = data.archive_file.qr_layer.output_path
  layer_name          = "${var.project_name}-qr-layer"
  compatible_runtimes = ["python3.12"]
  source_code_hash    = data.archive_file.qr_layer.output_base64sha256
}

# Step Function trigger Lambda
resource "aws_lambda_function" "step_function_trigger" {
  filename         = data.archive_file.step_function_trigger.output_path
  function_name    = "${var.project_name}-step-function-trigger"
  role            = aws_iam_role.lambda_role.arn
  handler         = "app.lambda_handler"
  runtime         = "python3.12"
  timeout         = 30
  source_code_hash = data.archive_file.step_function_trigger.output_base64sha256

  environment {
    variables = {
      STEP_FUNCTION_ARN = aws_sfn_state_machine.document_processor.arn
    }
  }
}

data "archive_file" "step_function_trigger" {
  type        = "zip"
  output_path = "${path.module}/../.build/step_function_trigger.zip"
  source {
    content = <<EOF
import json
import boto3
import os

def lambda_handler(event, context):
    step_functions = boto3.client('stepfunctions')
    
    for record in event['Records']:
        # Check if this is an INSERT event for DynamoDB Streams
        if record['eventName'] == 'INSERT':
            # Extract the new image data from DynamoDB event
            new_image = record['dynamodb'].get('NewImage', {})
            
            # Extract relevant fields from the DynamoDB record
            document_id = new_image.get('document_id', {}).get('S', '')
            s3_bucket = new_image.get('bucket', {}).get('S', '')
            s3_key = new_image.get('key', {}).get('S', '')
            
            if document_id and s3_bucket and s3_key:
                # For images only - create single image array
                input_data = {
                    "document_id": document_id,
                    "bucket": s3_bucket,
                    "key": s3_key,
                    "images": [
                        {
                            "page": 1,
                            "s3_key": s3_key
                        }
                    ]
                }
                
                step_functions.start_execution(
                    stateMachineArn=os.environ['STEP_FUNCTION_ARN'],
                    input=json.dumps(input_data)
                )
    
    return {'statusCode': 200}
EOF
    filename = "app.py"
  }
}

resource "aws_lambda_permission" "allow_dynamodb" {
  statement_id  = "AllowExecutionFromDynamoDBStream"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.step_function_trigger.function_name
  principal     = "dynamodb.amazonaws.com"
  source_arn    = aws_dynamodb_table.document_results.stream_arn
}

# DynamoDB Stream Event Source Mapping
resource "aws_lambda_event_source_mapping" "dynamodb_trigger" {
  event_source_arn  = aws_dynamodb_table.document_results.stream_arn
  function_name     = aws_lambda_function.step_function_trigger.arn
  starting_position = "LATEST"
  
  depends_on = [aws_lambda_permission.allow_dynamodb]
}

# Step Function State Machine
resource "aws_sfn_state_machine" "document_processor" {
  name     = "${var.project_name}-document-processor"
  role_arn = aws_iam_role.step_function_role.arn

  definition = jsonencode({
    Comment = "Document processing pipeline - Images only"
    StartAt = "ProcessImages"
    States = {
      ProcessImages = {
        Type = "Map"
        ItemsPath = "$.images"
        MaxConcurrency = 5
        Iterator = {
          StartAt = "ParallelProcessing"
          States = {
            ParallelProcessing = {
              Type = "Parallel"
              Branches = [
                {
                  StartAt = "QRScanner"
                  States = {
                    QRScanner = {
                      Type = "Task"
                      Resource = aws_lambda_function.qr_scanner.arn
                      End = true
                    }
                  }
                },
                {
                  StartAt = "OCRText"
                  States = {
                    OCRText = {
                      Type = "Task"
                      Resource = aws_lambda_function.ocr_text.arn
                      End = true
                    }
                  }
                }
              ]
              Next = "Validator"
            }
            Validator = {
              Type = "Task"
              Resource = aws_lambda_function.validator.arn
              End = true
            }
          }
        }
        End = true
      }
    }
  })
}

# Lambda Functions
data "archive_file" "qr_scanner" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/qr_scanner"
  output_path = "${path.module}/../.build/qr_scanner.zip"
  excludes    = ["__pycache__"]
}

resource "aws_lambda_function" "qr_scanner" {
  filename         = data.archive_file.qr_scanner.output_path
  function_name    = "${var.project_name}-qr-scanner"
  role            = aws_iam_role.lambda_role.arn
  handler         = "app.lambda_handler"
  runtime         = "python3.12"
  timeout         = 60
  memory_size     = 512
  source_code_hash = data.archive_file.qr_scanner.output_base64sha256

  layers = [aws_lambda_layer_version.common.arn, aws_lambda_layer_version.qr.arn]

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.document_bucket.bucket
    }
  }
}

data "archive_file" "ocr_text" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/ocr_text"
  output_path = "${path.module}/../.build/ocr_text.zip"
  excludes    = ["__pycache__"]
}

resource "aws_lambda_function" "ocr_text" {
  filename         = data.archive_file.ocr_text.output_path
  function_name    = "${var.project_name}-ocr-text"
  role            = aws_iam_role.lambda_role.arn
  handler         = "app.lambda_handler"
  runtime         = "python3.12"
  timeout         = 120
  memory_size     = 1024
  source_code_hash = data.archive_file.ocr_text.output_base64sha256

  layers = [aws_lambda_layer_version.common.arn, aws_lambda_layer_version.ocr.arn]

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.document_bucket.bucket
    }
  }
}

data "archive_file" "validator" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/validator"
  output_path = "${path.module}/../.build/validator.zip"
  excludes    = ["__pycache__"]
}

resource "aws_lambda_function" "validator" {
  filename         = data.archive_file.validator.output_path
  function_name    = "${var.project_name}-validator"
  role            = aws_iam_role.lambda_role.arn
  handler         = "app.lambda_handler"
  runtime         = "python3.12"
  timeout         = 60
  memory_size     = 256
  source_code_hash = data.archive_file.validator.output_base64sha256

  layers = [aws_lambda_layer_version.common.arn]

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.document_bucket.bucket
      DYNAMODB_TABLE = aws_dynamodb_table.document_results.name
    }
  }
}

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

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.document_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.step_function_trigger.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
    filter_suffix       = ".pdf"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# DynamoDB Table for results
resource "aws_dynamodb_table" "document_results" {
  name           = "${var.project_name}-results"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "document_id"

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
          aws_lambda_function.convert_to_image.arn,
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
    command = local.is_windows ? "powershell.exe -Command \"pip install -r '${path.module}/../layers/ocr/requirements.txt' -t '${path.module}/../.build/layers/ocr_deps' --platform linux_x86_64 --only-binary=:all:\"" : "pip3 install -r '${path.module}/../layers/ocr/requirements.txt' -t '${path.module}/../.build/layers/ocr_deps' --platform linux_x86_64 --only-binary=:all:"
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
    command = local.is_windows ? "powershell.exe -Command \"pip install -r '${path.module}/../layers/qr/requirements.txt' -t '${path.module}/../.build/layers/qr_deps' --platform linux_x86_64 --only-binary=:all:\"" : "pip3 install -r '${path.module}/../layers/qr/requirements.txt' -t '${path.module}/../.build/layers/qr_deps' --platform linux_x86_64 --only-binary=:all:"
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
from urllib.parse import unquote_plus

def lambda_handler(event, context):
    step_functions = boto3.client('stepfunctions')
    
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = unquote_plus(record['s3']['object']['key'])
        
        input_data = {
            "bucket": bucket,
            "key": key
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

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.step_function_trigger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.document_bucket.arn
}

# Step Function State Machine
resource "aws_sfn_state_machine" "document_processor" {
  name     = "${var.project_name}-document-processor"
  role_arn = aws_iam_role.step_function_role.arn

  definition = jsonencode({
    Comment = "Document processing pipeline"
    StartAt = "ConvertToImage"
    States = {
      ConvertToImage = {
        Type = "Task"
        Resource = aws_lambda_function.convert_to_image.arn
        Next = "ProcessImages"
        Retry = [
          {
            ErrorEquals = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts = 3
            BackoffRate = 2
          }
        ]
      }
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
data "archive_file" "convert_to_image" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/convert_to_image"
  output_path = "${path.module}/../.build/convert_to_image.zip"
  excludes    = ["__pycache__"]
}

resource "aws_lambda_function" "convert_to_image" {
  filename         = data.archive_file.convert_to_image.output_path
  function_name    = "${var.project_name}-convert-to-image"
  role            = aws_iam_role.lambda_role.arn
  handler         = "app.lambda_handler"
  runtime         = "python3.12"
  timeout         = 300
  memory_size     = 1024
  source_code_hash = data.archive_file.convert_to_image.output_base64sha256

  layers = [aws_lambda_layer_version.common.arn]

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.document_bucket.bucket
    }
  }
}

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

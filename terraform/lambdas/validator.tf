data "archive_file" "validator" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambdas/validator"
  output_path = "${path.module}/../../.build/validator.zip"
  excludes    = ["__pycache__"]
}

resource "aws_lambda_function" "validator" {
  filename         = data.archive_file.validator.output_path
  function_name    = "${var.project_name}-validator"
  role            = var.lambda_role_arn
  handler         = "app.lambda_handler"
  runtime         = "python3.12"
  timeout         = 60
  memory_size     = 256
  source_code_hash = data.archive_file.validator.output_base64sha256

  layers = [var.common_layer_arn]

  environment {
    variables = {
      BUCKET_NAME = var.bucket_name
      DYNAMODB_TABLE = var.dynamodb_table_name
    }
  }
}

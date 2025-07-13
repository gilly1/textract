data "archive_file" "ocr_text" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambdas/ocr_text"
  output_path = "${path.module}/../../.build/ocr_text.zip"
  excludes    = ["__pycache__"]
}

resource "aws_lambda_function" "ocr_text" {
  filename         = data.archive_file.ocr_text.output_path
  function_name    = "${var.project_name}-ocr-text"
  role            = var.lambda_role_arn
  handler         = "app.lambda_handler"
  runtime         = "python3.12"
  timeout         = 120
  memory_size     = 1024
  source_code_hash = data.archive_file.ocr_text.output_base64sha256

  layers = [var.common_layer_arn, var.ocr_layer_arn]

  environment {
    variables = {
      BUCKET_NAME = var.bucket_name
    }
  }
}

data "archive_file" "qr_scanner" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambdas/qr_scanner"
  output_path = "${path.module}/../../.build/qr_scanner.zip"
  excludes    = ["__pycache__"]
}

resource "aws_lambda_function" "qr_scanner" {
  filename         = data.archive_file.qr_scanner.output_path
  function_name    = "${var.project_name}-qr-scanner"
  role            = var.lambda_role_arn
  handler         = "app.lambda_handler"
  runtime         = "python3.12"
  timeout         = 60
  memory_size     = 512
  source_code_hash = data.archive_file.qr_scanner.output_base64sha256

  layers = [var.common_layer_arn, var.qr_layer_arn]

  environment {
    variables = {
      BUCKET_NAME = var.bucket_name
    }
  }
}

data "archive_file" "convert_to_image" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambdas/convert_to_image"
  output_path = "${path.module}/../../.build/convert_to_image.zip"
  excludes    = ["__pycache__"]
}

resource "aws_lambda_function" "convert_to_image" {
  filename         = data.archive_file.convert_to_image.output_path
  function_name    = "${var.project_name}-convert-to-image"
  role            = var.lambda_role_arn
  handler         = "app.lambda_handler"
  runtime         = "python3.12"
  timeout         = 300
  memory_size     = 1024
  source_code_hash = data.archive_file.convert_to_image.output_base64sha256

  layers = [var.common_layer_arn]

  environment {
    variables = {
      BUCKET_NAME = var.bucket_name
    }
  }
}

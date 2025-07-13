resource "aws_lambda_layer_version" "qr" {
  filename            = "${path.module}/../../.build/layers/qr.zip"
  layer_name          = "${var.project_name}-qr-layer"
  compatible_runtimes = ["python3.12"]
  source_code_hash    = filebase64sha256("${path.module}/../../.build/layers/qr.zip")
  
  depends_on = [
    null_resource.build_layers
  ]
}

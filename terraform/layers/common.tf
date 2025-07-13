resource "aws_lambda_layer_version" "common" {
  filename            = "${path.module}/../../.build/layers/common.zip"
  layer_name          = "${var.project_name}-common-layer"
  compatible_runtimes = ["python3.12"]
  source_code_hash    = filebase64sha256("${path.module}/../../.build/layers/common.zip")
  
  depends_on = [
    null_resource.build_layers
  ]
}

resource "null_resource" "build_layers" {
  triggers = {
    requirements_hash = filemd5("${path.module}/../../layers/common/python/utils/logger.py")
  }
  
  provisioner "local-exec" {
    command = "powershell.exe -ExecutionPolicy Bypass -File ${path.module}/../../scripts/build_layers.ps1"
    working_dir = path.module
  }
}

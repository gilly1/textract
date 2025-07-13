# Local values for cross-platform compatibility
locals {
  # Simple platform detection using path separator
  is_windows = substr(replace(path.cwd, "/", ""), 1, 1) == ":"
}

resource "null_resource" "build_layers" {
  triggers = {
    # This hashes the entire 'layers/common/python/utils' directory recursively
    requirements_hash = filesha256("${path.module}/../../layers/common/python/utils")
  }

  provisioner "local-exec" {
    command = local.is_windows  ? "powershell.exe -ExecutionPolicy Bypass -File ../../scripts/build_layers.ps1"  : "bash ../../scripts/build_layers.sh"

    working_dir = path.module
  }
}

resource "aws_lambda_layer_version" "common" {
  filename            = "${path.module}/../../.build/layers/common.zip"
  layer_name          = "${var.project_name}-common-layer"
  compatible_runtimes = ["python3.12"]
  source_code_hash    = filebase64sha256("${path.module}/../../.build/layers/common.zip")

  depends_on = [
    null_resource.build_layers
  ]
}

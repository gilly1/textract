output "common_layer_arn" {
  value = aws_lambda_layer_version.common.arn
}

output "ocr_layer_arn" {
  value = aws_lambda_layer_version.ocr.arn
}

output "qr_layer_arn" {
  value = aws_lambda_layer_version.qr.arn
}

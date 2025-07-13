output "convert_to_image_arn" {
  value = aws_lambda_function.convert_to_image.arn
}

output "qr_scanner_arn" {
  value = aws_lambda_function.qr_scanner.arn
}

output "ocr_text_arn" {
  value = aws_lambda_function.ocr_text.arn
}

output "validator_arn" {
  value = aws_lambda_function.validator.arn
}

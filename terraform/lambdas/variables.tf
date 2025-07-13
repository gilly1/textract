variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "common_layer_arn" {
  description = "ARN of the common layer"
  type        = string
}

variable "ocr_layer_arn" {
  description = "ARN of the OCR layer"
  type        = string
}

variable "qr_layer_arn" {
  description = "ARN of the QR layer"
  type        = string
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for document uploads"
  value       = aws_s3_bucket.document_bucket.bucket
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for results"
  value       = aws_dynamodb_table.document_results.name
}

output "step_function_arn" {
  description = "ARN of the Step Function state machine"
  value       = aws_sfn_state_machine.document_processor.arn
}

output "upload_url" {
  description = "S3 URL for uploading documents"
  value       = "s3://${aws_s3_bucket.document_bucket.bucket}/uploads/"
}

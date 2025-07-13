variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "document-processor"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

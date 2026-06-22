variable "tfstate_bucket" {
  description = "S3 bucket name to store Terraform state (must be unique globally)"
  type        = string
  default     = "onlineboutique-terraform-state"
}

variable "tfstate_lock_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "onlineboutique-terraform-locks"
}

variable "aws_region" {
  description = "AWS region for backend resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name used in state key path (eg: dev, staging, prod)"
  type        = string
  default     = "dev"
}

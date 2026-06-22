terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

// backend block removed temporarily to allow local apply operations
// Re-add or run `terraform init -backend-config=backend.s3.conf -migrate-state`
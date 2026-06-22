# Bootstrap resources for Terraform remote backend
# Note: terraform block and provider are defined in terraform.tf

# KMS key for S3 encryption
resource "aws_kms_key" "tfstate" {
  description             = "KMS key for Terraform state encryption (${var.environment})"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name        = "terraform-state-key-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "tfstate" {
  name          = "alias/terraform-state-${var.environment}"
  target_key_id = aws_kms_key.tfstate.key_id
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "tfstate" {
  bucket = var.tfstate_bucket

  tags = {
    Name        = "terraform-state-${var.environment}"
    Environment = var.environment
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Block all public access to state bucket
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for state recovery
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption with KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tfstate.arn
    }
    bucket_key_enabled = true
  }
}

# Deny unencrypted uploads and enforce secure transport
resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # NOTE: Explicit deny for uploads without SSE header removed to
      # allow Terraform to upload state even if it doesn't set the
      # aws:kms header. The bucket still has default SSE with KMS and
      # a transport-security deny remains below.
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.tfstate.arn,
          "${aws_s3_bucket.tfstate.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Enable logging for state bucket (optional but recommended)
resource "aws_s3_bucket_logging" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  target_bucket = aws_s3_bucket.tfstate_logs.id
  target_prefix = "tfstate-access-logs/"
}

# S3 bucket for access logs
resource "aws_s3_bucket" "tfstate_logs" {
  bucket = "${var.tfstate_bucket}-logs"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "terraform-state-logs-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate_logs" {
  bucket = aws_s3_bucket.tfstate_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "tf_locks" {
  name             = var.tfstate_lock_table
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "LockID"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name        = "terraform-locks-${var.environment}"
    Environment = var.environment
  }

  lifecycle {
    prevent_destroy = true
  }
}

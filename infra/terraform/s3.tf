# S3 bucket for MongoDB backups (Wiz Project)
resource "aws_s3_bucket" "mongo_backups" {
  bucket        = "tasky-wiz-mongo-backups-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name        = "tasky-wiz-mongo-backups"
    Environment = "wiz-lab"
    Project     = "Tasky"
  }
}

# Versioning
resource "aws_s3_bucket_versioning" "mongo_backups_versioning" {
  bucket = aws_s3_bucket.mongo_backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "mongo_backups" {
  bucket                  = aws_s3_bucket.mongo_backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# KMS key for S3 encryption
resource "aws_kms_key" "mongo_backups_key" {
  description             = "KMS key for Mongo backup bucket encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "tasky-wiz-mongo-backups-kms"
    Environment = "wiz-lab"
    Project     = "Tasky"
  }
}

# Default encryption using that KMS key
resource "aws_s3_bucket_server_side_encryption_configuration" "mongo_backups_encryption" {
  bucket = aws_s3_bucket.mongo_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.mongo_backups_key.arn
    }
  }
}

output "mongo_backup_bucket" {
  value = aws_s3_bucket.mongo_backups.bucket
}

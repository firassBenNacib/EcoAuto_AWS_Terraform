locals {
  s3_encryption_algorithm = var.enable_kms_encryption ? "aws:kms" : "AES256"
}

#tfsec:ignore:aws-s3-enable-bucket-logging Access logging bucket is optional in this cost profile.
resource "aws_s3_bucket" "frontend" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_ownership_controls" "frontend_ownership" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend_encryption" {
  #tfsec:ignore:aws-s3-encryption-customer-key Cost-optimized default uses SSE-S3; enable_kms_encryption toggles SSE-KMS.
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.s3_encryption_algorithm
      kms_master_key_id = var.enable_kms_encryption ? var.kms_key_id : null
    }
  }
}

resource "aws_s3_bucket_versioning" "frontend_versioning" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend_public_block" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "frontend_lifecycle" {
  count = var.enable_lifecycle ? 1 : 0

  bucket = aws_s3_bucket.frontend.id

  rule {
    id     = "default-lifecycle"
    status = "Enabled"

    dynamic "expiration" {
      for_each = var.lifecycle_expiration_days != null ? [1] : []
      content {
        days = var.lifecycle_expiration_days
      }
    }

    dynamic "noncurrent_version_expiration" {
      for_each = var.versioning_enabled && var.lifecycle_noncurrent_expiration_days != null ? [1] : []
      content {
        noncurrent_days = var.lifecycle_noncurrent_expiration_days
      }
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = var.lifecycle_abort_incomplete_multipart_upload_days
    }
  }
}

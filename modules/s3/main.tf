data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "frontend" {
  bucket        = var.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend_encryption" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "frontend_versioning" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration {
    status = "Disabled"
  }
}



resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend.id
  policy = templatefile("${path.module}/s3_policy.json.tpl", {
    cloudfront_arn = var.cloudfront_arn
    bucket_name    = var.bucket_name
    account_id     = data.aws_caller_identity.current.account_id
  })
}

resource "aws_s3_bucket_public_access_block" "frontend_public_block" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

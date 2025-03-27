variable "bucket_name" {
  description = "S3 bucket name for hosting frontend"
  type        = string
}

variable "cloudfront_arn" {
  description = "CloudFront distribution ARN for bucket policy"
  type        = string
}

output "bucket_name" {
  value = aws_s3_bucket.frontend.id
}

output "bucket_domain_name" {
  value = aws_s3_bucket.frontend.bucket_regional_domain_name
}

output "backend_url" {
  value = aws_cloudfront_distribution.backend.domain_name
}

output "backend_distribution_id" {
  value = aws_cloudfront_distribution.backend.id
}

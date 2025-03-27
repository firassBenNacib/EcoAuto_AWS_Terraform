output "frontend_url" {
  value = aws_cloudfront_distribution.frontend.domain_name
}

output "frontend_distribution_id" {
  value = aws_cloudfront_distribution.frontend.id
}

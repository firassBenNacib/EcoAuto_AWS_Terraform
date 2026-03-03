output "frontend_url" {
  value = aws_cloudfront_distribution.frontend.domain_name
}

output "frontend_distribution_id" {
  value = aws_cloudfront_distribution.frontend.id
}

output "frontend_distribution_arn" {
  value = aws_cloudfront_distribution.frontend.arn
}

output "frontend_hosted_zone_id" {
  value = aws_cloudfront_distribution.frontend.hosted_zone_id
}

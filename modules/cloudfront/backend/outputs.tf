output "backend_url" {
  value = coalesce(
    try(aws_cloudfront_distribution.backend_dynamic[0].domain_name, null),
    try(aws_cloudfront_distribution.backend_strict[0].domain_name, null)
  )
}

output "backend_distribution_id" {
  value = coalesce(
    try(aws_cloudfront_distribution.backend_dynamic[0].id, null),
    try(aws_cloudfront_distribution.backend_strict[0].id, null)
  )
}

output "backend_distribution_arn" {
  value = coalesce(
    try(aws_cloudfront_distribution.backend_dynamic[0].arn, null),
    try(aws_cloudfront_distribution.backend_strict[0].arn, null)
  )
}

output "backend_hosted_zone_id" {
  value = coalesce(
    try(aws_cloudfront_distribution.backend_dynamic[0].hosted_zone_id, null),
    try(aws_cloudfront_distribution.backend_strict[0].hosted_zone_id, null)
  )
}

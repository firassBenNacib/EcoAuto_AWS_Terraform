output "backend_ec2_sg_id" {
  description = "Security group ID for backend EC2 instances"
  value       = aws_security_group.backend_ec2.id
}

output "rds_sg_id" {
  description = "Security group ID for RDS"
  value       = aws_security_group.rds.id
}

output "cloudfront_origin_prefix_list_id" {
  description = "Managed prefix list ID used for CloudFront origin-facing ingress"
  value       = data.aws_ec2_managed_prefix_list.cloudfront_origin_facing.id
}

output "cloudfront_origin_prefix_list_max_entries" {
  description = "Max entries/weight of the CloudFront managed prefix list (impacts SG rule quotas)"
  value       = data.aws_ec2_managed_prefix_list.cloudfront_origin_facing.max_entries
}

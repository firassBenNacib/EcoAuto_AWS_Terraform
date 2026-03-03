output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "public_app_subnet_ids" {
  description = "Public subnet IDs used by backend EC2"
  value       = aws_subnet.public_app[*].id
}

output "private_db_subnet_ids" {
  description = "Private subnet IDs used by RDS"
  value       = aws_subnet.private_db[*].id
}

output "vpc_flow_logs_log_group_name" {
  description = "VPC Flow Logs CloudWatch log group name when enabled"
  value       = try(aws_cloudwatch_log_group.vpc_flow_logs[0].name, null)
}

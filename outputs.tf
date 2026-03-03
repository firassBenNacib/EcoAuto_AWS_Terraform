output "vpc_id" {
  value = local.selected_vpc_id
}

output "public_app_subnet_ids" {
  value = local.selected_public_subnet_ids
}

output "db_subnet_ids" {
  value = local.selected_db_subnet_ids
}

output "backend_cloudfront_url" {
  value = module.cloudfront_backend.backend_url
}

output "backend_cloudfront_distribution_id" {
  value       = module.cloudfront_backend.backend_distribution_id
  description = "Backend CloudFront distribution ID used by update-infra Lambda."
}

output "frontend_cloudfront_url" {
  value = module.cloudfront_frontend.frontend_url
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "ec2_asg_name" {
  value = module.ec2.asg_name
}

output "backend_ec2_security_group_id" {
  value = module.security_groups.backend_ec2_sg_id
}

output "cloudfront_origin_prefix_list_id" {
  value       = module.security_groups.cloudfront_origin_prefix_list_id
  description = "CloudFront managed prefix list ID used for backend SG ingress."
}

output "cloudfront_origin_prefix_list_max_entries" {
  value       = module.security_groups.cloudfront_origin_prefix_list_max_entries
  description = "CloudFront managed prefix list max entries/weight used for SG quota planning."
}

output "rds_security_group_id" {
  value = module.security_groups.rds_sg_id
}

output "snapshot_cleanup_lambda_arn" {
  value = module.lambda.delete_old_snapshots_arn
}

output "origin_health_probe_rule_name" {
  value = module.cloudwatch_events.origin_health_probe_rule_name
}

output "update_infra_error_alarm_name" {
  value = module.lambda.update_infra_error_alarm_name
}

output "update_infra_alarm_sns_topic_arn" {
  value       = try(aws_sns_topic.update_infra_alarm[0].arn, null)
  description = "SNS topic ARN used by update-infra error alarm when create_update_infra_alarm_sns_topic=true."
}

output "lambda_async_failure_queue_arn" {
  value       = module.lambda.async_failure_queue_arn
  description = "SQS queue ARN used for Lambda async failures and EventBridge dead-letter delivery."
}

output "update_infra_invoke_command" {
  value       = "aws lambda invoke --region ${var.aws_region} --function-name ${module.lambda.update_infra_lambda_name} /tmp/update_infra_output.json"
  description = "Manual runbook command to trigger update-infra Lambda on demand."
}

output "cloudfront_logs_bucket_name" {
  value       = try(aws_s3_bucket.cloudfront_logs[0].id, null)
  description = "CloudFront access logs bucket when enable_cloudfront_access_logs=true."
}

output "vpc_flow_logs_log_group_name" {
  value       = var.use_default_vpc ? null : module.network[0].vpc_flow_logs_log_group_name
  description = "VPC Flow Logs log group name when enable_vpc_flow_logs=true and use_default_vpc=false."
}

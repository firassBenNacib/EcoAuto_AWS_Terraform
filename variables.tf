variable "compatibility_mode" {
  description = "Deployment mode. 'template' keeps explicit domains/names; 'workspace' enables workspace-derived aliases and naming."
  type        = string
  default     = "template"

  validation {
    condition     = contains(["template", "workspace"], var.compatibility_mode)
    error_message = "compatibility_mode must be either 'template' or 'workspace'."
  }
}

variable "workspace_domain" {
  description = "Base domain used when compatibility_mode is 'workspace' (for example: example.com)"
  type        = string
  default     = ""

  validation {
    condition     = var.compatibility_mode != "workspace" || trimspace(var.workspace_domain) != ""
    error_message = "workspace_domain must be set when compatibility_mode is 'workspace'."
  }
}

variable "workspace_backend_subdomain" {
  description = "Backend API subdomain prefix used in workspace mode"
  type        = string
  default     = "api"
}

variable "workspace_bootstrap_origin_domain" {
  description = "Optional bootstrap backend origin domain used only in workspace mode"
  type        = string
  default     = ""
}

variable "append_workspace_to_bucket_name" {
  description = "Append -<workspace> to the S3 bucket name in workspace mode"
  type        = bool
  default     = false
}

variable "use_default_vpc" {
  description = "Use default VPC/subnets instead of creating dedicated network module resources"
  type        = bool
  default     = false
}

variable "allow_default_vpc_outside_prod" {
  description = "Allow use_default_vpc=true in non-prod workspaces. Set false to enforce dedicated VPC in all environments."
  type        = bool
  default     = true
}

variable "enable_observability_addons" {
  description = "Enable additional observability features that increase cost (currently VPC Flow Logs and CloudFront access logs)."
  type        = bool
  default     = false
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs for the dedicated VPC created by modules/network (also enabled when enable_observability_addons=true)"
  type        = bool
  default     = false
}

variable "vpc_flow_logs_retention_days" {
  description = "CloudWatch log retention days for VPC Flow Logs"
  type        = number
  default     = 30

  validation {
    condition     = var.vpc_flow_logs_retention_days >= 1
    error_message = "vpc_flow_logs_retention_days must be >= 1."
  }
}

variable "lockdown_default_security_group" {
  description = "When true, remove all ingress/egress rules from the default security group of the dedicated VPC"
  type        = bool
  default     = true
}

variable "enable_snapshot_cleanup" {
  description = "Enable daily RDS manual snapshot cleanup Lambda and EventBridge rule"
  type        = bool
  default     = true
}

variable "snapshot_retention_days" {
  description = "Delete RDS manual snapshots older than this many days (while keeping a minimum recent set)"
  type        = number
  default     = 14

  validation {
    condition     = var.snapshot_retention_days >= 1 && var.snapshot_retention_days == floor(var.snapshot_retention_days)
    error_message = "snapshot_retention_days must be an integer >= 1."
  }
}

variable "snapshot_min_keep_count" {
  description = "Minimum number of newest manual RDS snapshots to keep regardless of age"
  type        = number
  default     = 3

  validation {
    condition     = var.snapshot_min_keep_count >= 1 && var.snapshot_min_keep_count == floor(var.snapshot_min_keep_count)
    error_message = "snapshot_min_keep_count must be an integer >= 1."
  }
}

variable "aws_region" {
  description = "AWS region for primary resources"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name tag applied to resources"
  type        = string
  default     = "ecoauto"
}

variable "additional_tags" {
  description = "Additional tags applied to resources through provider default tags"
  type        = map(string)
  default     = {}
}

variable "vpc_name" {
  description = "Name for the VPC"
  type        = string
  default     = "ecoauto-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = []
}

variable "public_app_subnet_cidrs" {
  description = "CIDR blocks for public application subnets"
  type        = list(string)
  default     = []
}

variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for private database subnets"
  type        = list(string)
  default     = []
}

variable "bucket_name" {
  description = "Name of the frontend S3 bucket"
  type        = string
}

variable "s3_force_destroy" {
  description = "Allow destroying non-empty frontend S3 bucket (not recommended for production)"
  type        = bool
  default     = false
}

variable "s3_versioning_enabled" {
  description = "Enable frontend bucket versioning"
  type        = bool
  default     = true
}

variable "enable_s3_kms_encryption" {
  description = "Enable SSE-KMS for the frontend S3 bucket instead of SSE-S3 (AES256)"
  type        = bool
  default     = false
}

variable "s3_kms_key_id" {
  description = "KMS key ID/ARN used for frontend S3 bucket encryption when enable_s3_kms_encryption=true"
  type        = string
  default     = null
}

variable "enable_s3_lifecycle" {
  description = "Enable lifecycle rules on the frontend S3 bucket"
  type        = bool
  default     = false
}

variable "s3_lifecycle_expiration_days" {
  description = "Optional expiration age (days) for current frontend S3 objects"
  type        = number
  default     = null
}

variable "s3_lifecycle_noncurrent_expiration_days" {
  description = "Optional expiration age (days) for noncurrent frontend S3 object versions"
  type        = number
  default     = 30
}

variable "s3_lifecycle_abort_incomplete_multipart_upload_days" {
  description = "Abort incomplete multipart uploads in frontend S3 bucket after this many days"
  type        = number
  default     = 7

  validation {
    condition     = var.s3_lifecycle_abort_incomplete_multipart_upload_days >= 1 && var.s3_lifecycle_abort_incomplete_multipart_upload_days == floor(var.s3_lifecycle_abort_incomplete_multipart_upload_days)
    error_message = "s3_lifecycle_abort_incomplete_multipart_upload_days must be an integer >= 1."
  }
}

variable "ec2_ami_id" {
  description = "AMI ID for backend EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.micro"
}

variable "ec2_key_name" {
  description = "Optional key pair name for EC2 SSH access"
  type        = string
  default     = null
}

variable "ec2_root_block_device_name" {
  description = "Root block device name for backend EC2 launch template"
  type        = string
  default     = "/dev/xvda"
}

variable "ec2_root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 20
}

variable "ec2_root_volume_type" {
  description = "Root EBS volume type for backend EC2"
  type        = string
  default     = "gp3"
}

variable "ec2_ebs_kms_key_id" {
  description = "Optional KMS key ID/ARN for backend EC2 root volume encryption"
  type        = string
  default     = null
}

variable "launch_template_prefix" {
  description = "Launch template name prefix"
  type        = string
  default     = "ecoauto-backend-lt-"
}

variable "ec2_instance_name" {
  description = "Name tag for backend instances"
  type        = string
  default     = "ecoauto-backend"
}

variable "user_data_script" {
  description = "User-data script filename under modules/ec2/user-data"
  type        = string
  default     = "your-user-data-script.sh"
}

variable "asg_name" {
  description = "Auto Scaling Group name"
  type        = string
  default     = "ecoauto-backend-asg"
}

variable "desired_capacity" {
  description = "Desired number of EC2 instances"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of EC2 instances"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of EC2 instances"
  type        = number
  default     = 1
}

variable "cpu_target_value" {
  description = "Target CPU utilization for ASG scaling policy"
  type        = number
  default     = 70
}

variable "asg_health_check_grace_period" {
  description = "Health check grace period (seconds) for backend ASG EC2 health checks"
  type        = number
  default     = 180

  validation {
    condition     = var.asg_health_check_grace_period >= 0 && var.asg_health_check_grace_period <= 7200 && var.asg_health_check_grace_period == floor(var.asg_health_check_grace_period)
    error_message = "asg_health_check_grace_period must be an integer between 0 and 7200."
  }
}

variable "asg_default_instance_warmup" {
  description = "Default warmup time (seconds) used by ASG scaling/refresh operations"
  type        = number
  default     = 180

  validation {
    condition     = var.asg_default_instance_warmup >= 0 && var.asg_default_instance_warmup <= 7200 && var.asg_default_instance_warmup == floor(var.asg_default_instance_warmup)
    error_message = "asg_default_instance_warmup must be an integer between 0 and 7200."
  }
}

variable "enable_asg_instance_refresh" {
  description = "Enable rolling ASG instance refresh on launch template changes"
  type        = bool
  default     = true
}

variable "asg_instance_refresh_min_healthy_percentage" {
  description = "Minimum healthy instance percentage maintained during ASG instance refresh"
  type        = number
  default     = 50

  validation {
    condition     = var.asg_instance_refresh_min_healthy_percentage >= 0 && var.asg_instance_refresh_min_healthy_percentage <= 100 && var.asg_instance_refresh_min_healthy_percentage == floor(var.asg_instance_refresh_min_healthy_percentage)
    error_message = "asg_instance_refresh_min_healthy_percentage must be an integer between 0 and 100."
  }
}

variable "asg_instance_refresh_warmup_seconds" {
  description = "Per-batch warmup time (seconds) for ASG instance refresh"
  type        = number
  default     = 180

  validation {
    condition     = var.asg_instance_refresh_warmup_seconds >= 0 && var.asg_instance_refresh_warmup_seconds <= 7200 && var.asg_instance_refresh_warmup_seconds == floor(var.asg_instance_refresh_warmup_seconds)
    error_message = "asg_instance_refresh_warmup_seconds must be an integer between 0 and 7200."
  }
}

variable "backend_port" {
  description = "Backend application port"
  type        = number
  default     = 8080
}

variable "backend_origin_protocol_policy" {
  description = "CloudFront-to-origin protocol policy for backend origin"
  type        = string
  default     = "http-only"

  validation {
    condition     = contains(["http-only", "https-only"], var.backend_origin_protocol_policy)
    error_message = "backend_origin_protocol_policy must be either 'http-only' or 'https-only'."
  }
}

variable "allow_backend_https_origin_with_dynamic_public_dns" {
  description = "Acknowledge and allow backend_origin_protocol_policy=https-only when origins are dynamic EC2 PublicDnsName values. Requires matching origin TLS cert strategy."
  type        = bool
  default     = false
}

variable "backend_viewer_protocol_policy" {
  description = "Viewer protocol policy for backend CloudFront distribution"
  type        = string
  default     = "redirect-to-https"

  validation {
    condition     = contains(["allow-all", "redirect-to-https", "https-only"], var.backend_viewer_protocol_policy)
    error_message = "backend_viewer_protocol_policy must be one of allow-all, redirect-to-https, or https-only."
  }
}

variable "backend_ignore_dynamic_origin_drift" {
  description = "When true, ignore backend CloudFront origin drift managed by update-infra Lambda; set false for strict Terraform origin drift enforcement."
  type        = bool
  default     = true
}

variable "app_port" {
  description = "Deprecated alias of backend_port. If set, this value overrides backend_port."
  type        = number
  default     = null
}

variable "enable_ssh_admin" {
  description = "Enable direct SSH to backend instances from admin_cidr"
  type        = bool
  default     = false
}

variable "allow_ssh_admin_in_prod" {
  description = "Allow SSH admin ingress in prod workspace when enable_ssh_admin is true"
  type        = bool
  default     = false
}

variable "admin_cidr" {
  description = "Admin CIDR used when SSH access is enabled"
  type        = string
  default     = "203.0.113.10/32"
}

variable "enable_origin_auth_header" {
  description = "Enable CloudFront origin custom-header authentication for backend origin protection"
  type        = bool
  default     = true
}

variable "origin_auth_header_name" {
  description = "Primary custom header name used for backend origin authentication"
  type        = string
  default     = "X-Origin-Verify"
}

variable "origin_auth_header_value" {
  description = "Primary custom header value used for backend origin authentication"
  type        = string
  default     = ""
  sensitive   = true
}

variable "origin_auth_previous_header_name" {
  description = "Secondary custom header name used during origin auth secret rotation"
  type        = string
  default     = "X-Origin-Verify-Prev"

  validation {
    condition     = trimspace(var.origin_auth_previous_header_name) != ""
    error_message = "origin_auth_previous_header_name must not be empty."
  }
}

variable "origin_auth_previous_header_value" {
  description = "Secondary custom header value used during origin auth secret rotation"
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = trimspace(var.origin_auth_previous_header_value) == "" || trimspace(var.origin_auth_previous_header_value) != trimspace(var.origin_auth_header_value)
    error_message = "origin_auth_previous_header_value must differ from origin_auth_header_value when set."
  }
}

variable "enable_origin_health_probe" {
  description = "Enable scheduled backend origin health probing and origin-list refresh"
  type        = bool
  default     = false
}

variable "origin_health_fail_open" {
  description = "When health probes find no healthy origins, continue reconciliation using all running ASG origins instead of leaving CloudFront origins unchanged."
  type        = bool
  default     = true
}

variable "origin_health_path" {
  description = "HTTP path used by update-infra Lambda to probe origin health"
  type        = string
  default     = "/health"

  validation {
    condition     = trimspace(var.origin_health_path) != ""
    error_message = "origin_health_path must not be empty."
  }
}

variable "origin_health_interval_minutes" {
  description = "Schedule interval (minutes) for origin health probe refresh"
  type        = number
  default     = 5

  validation {
    condition     = var.origin_health_interval_minutes >= 1 && var.origin_health_interval_minutes == floor(var.origin_health_interval_minutes)
    error_message = "origin_health_interval_minutes must be an integer >= 1."
  }
}

variable "origin_health_timeout_seconds" {
  description = "Timeout (seconds) per origin health probe request"
  type        = number
  default     = 2

  validation {
    condition     = var.origin_health_timeout_seconds >= 1 && var.origin_health_timeout_seconds <= 30 && var.origin_health_timeout_seconds == floor(var.origin_health_timeout_seconds)
    error_message = "origin_health_timeout_seconds must be an integer between 1 and 30."
  }
}

variable "enable_update_infra_alarm" {
  description = "Enable CloudWatch alarm for failed update-infra Lambda invocations"
  type        = bool
  default     = true
}

variable "update_infra_alarm_actions" {
  description = "Optional SNS topic ARNs (or other alarm actions) for update-infra Lambda error alarm"
  type        = list(string)
  default     = []
}

variable "create_update_infra_alarm_sns_topic" {
  description = "Create a dedicated SNS topic and attach it to the update-infra error alarm when enabled."
  type        = bool
  default     = true
}

variable "update_infra_alarm_email_endpoints" {
  description = "Optional email recipients subscribed to the dedicated update-infra alarm SNS topic."
  type        = list(string)
  default     = []
}

variable "update_infra_alarm_sns_kms_key_id" {
  description = "KMS key ID/ARN/alias used to encrypt the dedicated update-infra alarm SNS topic."
  type        = string
  default     = "alias/aws/sns"
}

variable "acm_cert_backend" {
  description = "ACM certificate ARN for backend CloudFront distribution (must be us-east-1)"
  type        = string
}

variable "acm_cert_frontend" {
  description = "ACM certificate ARN for frontend CloudFront distribution (must be us-east-1)"
  type        = string
}

variable "backend_bootstrap_origin_domain" {
  description = "Initial backend origin domain used by CloudFront before Lambda updates origins"
  type        = string
  default     = "placeholder-backend.example.com"
}

variable "frontend_domain" {
  description = "Frontend apex domain used in template mode"
  type        = string
  default     = "example.com"
}

variable "backend_domain" {
  description = "Backend API domain used in template mode"
  type        = string
  default     = "api.example.com"
}

variable "backend_cache_policy_id" {
  description = "CloudFront cache policy ID for backend distribution"
  type        = string
}

variable "backend_origin_request_policy_id" {
  description = "CloudFront origin request policy ID for backend distribution"
  type        = string
}

variable "backend_geo_locations" {
  description = "Allowed geo locations for backend CloudFront distribution"
  type        = list(string)
  default     = ["US", "GB", "CA"]
}

variable "backend_price_class" {
  description = "CloudFront price class for backend distribution"
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.backend_price_class)
    error_message = "backend_price_class must be one of PriceClass_All, PriceClass_200, or PriceClass_100."
  }
}

variable "frontend_cache_policy_id" {
  description = "CloudFront cache policy ID for frontend distribution"
  type        = string
  default     = "658327ea-f89d-4fab-a63d-7e88639e58f6"
}

variable "frontend_price_class" {
  description = "CloudFront price class for frontend distribution"
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.frontend_price_class)
    error_message = "frontend_price_class must be one of PriceClass_All, PriceClass_200, or PriceClass_100."
  }
}

variable "frontend_response_headers_policy_id" {
  description = "CloudFront response headers policy ID for frontend distribution"
  type        = string
  default     = "67f7725c-6f97-4210-82d7-5512b31e9d03"
}

variable "frontend_viewer_protocol_policy" {
  description = "Viewer protocol policy for frontend CloudFront distribution"
  type        = string
  default     = "https-only"

  validation {
    condition     = contains(["allow-all", "redirect-to-https", "https-only"], var.frontend_viewer_protocol_policy)
    error_message = "frontend_viewer_protocol_policy must be one of allow-all, redirect-to-https, or https-only."
  }
}

variable "frontend_web_acl_arn" {
  description = "Optional WAFv2 Web ACL ARN for frontend CloudFront distribution"
  type        = string
  default     = null
}

variable "backend_web_acl_arn" {
  description = "Optional WAFv2 Web ACL ARN for backend CloudFront distribution"
  type        = string
  default     = null
}

variable "enable_cloudfront_access_logs" {
  description = "Enable CloudFront standard access logs for frontend and backend distributions (also enabled when enable_observability_addons=true)"
  type        = bool
  default     = false
}

variable "cloudfront_logs_bucket_name" {
  description = "S3 bucket name used to store CloudFront access logs when enable_cloudfront_access_logs=true"
  type        = string
  default     = ""
}

variable "cloudfront_logs_prefix" {
  description = "Prefix for CloudFront access logs objects"
  type        = string
  default     = "cloudfront/"
}

variable "enable_cloudfront_logs_lifecycle" {
  description = "Enable lifecycle expiration for CloudFront access logs bucket when logs are enabled"
  type        = bool
  default     = true
}

variable "cloudfront_logs_expiration_days" {
  description = "Expire CloudFront access log objects after this many days"
  type        = number
  default     = 90

  validation {
    condition     = var.cloudfront_logs_expiration_days >= 1 && var.cloudfront_logs_expiration_days == floor(var.cloudfront_logs_expiration_days)
    error_message = "cloudfront_logs_expiration_days must be an integer >= 1."
  }
}

variable "cloudfront_logs_abort_incomplete_multipart_upload_days" {
  description = "Abort incomplete multipart uploads in CloudFront logs bucket after this many days"
  type        = number
  default     = 7

  validation {
    condition     = var.cloudfront_logs_abort_incomplete_multipart_upload_days >= 1 && var.cloudfront_logs_abort_incomplete_multipart_upload_days == floor(var.cloudfront_logs_abort_incomplete_multipart_upload_days)
    error_message = "cloudfront_logs_abort_incomplete_multipart_upload_days must be an integer >= 1."
  }
}

variable "rds_identifier" {
  description = "RDS instance identifier"
  type        = string
  default     = "ecoauto-rds"
}

variable "rds_db_name" {
  description = "Database name"
  type        = string
  default     = "ecoauto"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false
}

variable "rds_backup_retention_period" {
  description = "RDS backup retention period in days"
  type        = number
  default     = 7
}

variable "rds_deletion_protection" {
  description = "Enable RDS deletion protection"
  type        = bool
  default     = false
}

variable "rds_skip_final_snapshot" {
  description = "Skip final snapshot when deleting RDS"
  type        = bool
  default     = true
}

variable "rds_final_snapshot_identifier" {
  description = "Optional final snapshot identifier used when rds_skip_final_snapshot is false"
  type        = string
  default     = null
}

variable "enable_rds_iam_auth" {
  description = "Enable IAM database authentication for RDS MySQL"
  type        = bool
  default     = true
}

variable "rds_username" {
  description = "RDS master username"
  type        = string
}

variable "rds_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "kms_key_id" {
  description = "Optional KMS key ARN for RDS encryption"
  type        = string
  default     = null
}

variable "route53_zone_id" {
  description = "Route 53 public hosted zone ID"
  type        = string
}

variable "start_schedule_expression" {
  description = "EventBridge schedule expression for starting compute resources"
  type        = string
  default     = "cron(0 7 * * ? *)"
}

variable "stop_schedule_expression" {
  description = "EventBridge schedule expression for stopping compute resources"
  type        = string
  default     = "cron(0 1 * * ? *)"
}

variable "enable_compute_start_stop_schedule" {
  description = "Enable EventBridge schedules for start/stop automation of ASG and RDS."
  type        = bool
  default     = true
}

variable "snapshot_cleanup_schedule_expression" {
  description = "EventBridge schedule expression for snapshot cleanup"
  type        = string
  default     = "cron(0 22 * * ? *)"
}

variable "eventbridge_lambda_retry_attempts" {
  description = "Maximum EventBridge retry attempts when invoking Lambda targets"
  type        = number
  default     = 6

  validation {
    condition     = var.eventbridge_lambda_retry_attempts >= 0 && var.eventbridge_lambda_retry_attempts <= 185 && var.eventbridge_lambda_retry_attempts == floor(var.eventbridge_lambda_retry_attempts)
    error_message = "eventbridge_lambda_retry_attempts must be an integer between 0 and 185."
  }
}

variable "eventbridge_lambda_max_event_age_seconds" {
  description = "Maximum age (seconds) of an EventBridge event for Lambda target retries"
  type        = number
  default     = 3600

  validation {
    condition     = var.eventbridge_lambda_max_event_age_seconds >= 60 && var.eventbridge_lambda_max_event_age_seconds <= 86400 && var.eventbridge_lambda_max_event_age_seconds == floor(var.eventbridge_lambda_max_event_age_seconds)
    error_message = "eventbridge_lambda_max_event_age_seconds must be an integer between 60 and 86400."
  }
}

variable "eventbridge_stop_lambda_retry_attempts" {
  description = "EventBridge retry attempts for the stop-resources Lambda target (higher default reduces missed stop windows)"
  type        = number
  default     = 24

  validation {
    condition     = var.eventbridge_stop_lambda_retry_attempts >= 0 && var.eventbridge_stop_lambda_retry_attempts <= 185 && var.eventbridge_stop_lambda_retry_attempts == floor(var.eventbridge_stop_lambda_retry_attempts)
    error_message = "eventbridge_stop_lambda_retry_attempts must be an integer between 0 and 185."
  }
}

variable "eventbridge_stop_lambda_max_event_age_seconds" {
  description = "EventBridge max event age (seconds) for the stop-resources Lambda target"
  type        = number
  default     = 21600

  validation {
    condition     = var.eventbridge_stop_lambda_max_event_age_seconds >= 60 && var.eventbridge_stop_lambda_max_event_age_seconds <= 86400 && var.eventbridge_stop_lambda_max_event_age_seconds == floor(var.eventbridge_stop_lambda_max_event_age_seconds)
    error_message = "eventbridge_stop_lambda_max_event_age_seconds must be an integer between 60 and 86400."
  }
}

variable "lambda_log_retention_days" {
  description = "CloudWatch log retention (days) for regional and Lambda@Edge functions"
  type        = number
  default     = 30
}

variable "lambda_log_kms_key_id" {
  description = "Optional KMS key ARN for Lambda CloudWatch log groups"
  type        = string
  default     = null
}

variable "manage_lambda_log_groups" {
  description = "Create and manage Terraform-owned log groups for UpdateInfra/StopEC2RDS/DeleteSnapshots Lambdas. Disable when these log groups already exist and should be left unmanaged."
  type        = bool
  default     = true
}

variable "update_infra_reserved_concurrent_executions" {
  description = "Reserved concurrency for UpdateInfra Lambda. Use -1 to disable reserved concurrency."
  type        = number
  default     = 1

  validation {
    condition     = var.update_infra_reserved_concurrent_executions >= -1 && var.update_infra_reserved_concurrent_executions == floor(var.update_infra_reserved_concurrent_executions)
    error_message = "update_infra_reserved_concurrent_executions must be an integer greater than or equal to -1."
  }
}

variable "enable_lambda_xray_tracing" {
  description = "Enable AWS X-Ray tracing for regional Lambda functions"
  type        = bool
  default     = true
}

variable "enable_lambda_async_failure_queue" {
  description = "Enable shared SQS async failure queue for Lambda DLQ/on-failure destinations"
  type        = bool
  default     = true
}

variable "lambda_async_failure_queue_message_retention_seconds" {
  description = "Retention period for Lambda async failure queue messages"
  type        = number
  default     = 1209600

  validation {
    condition     = var.lambda_async_failure_queue_message_retention_seconds >= 60 && var.lambda_async_failure_queue_message_retention_seconds <= 1209600 && var.lambda_async_failure_queue_message_retention_seconds == floor(var.lambda_async_failure_queue_message_retention_seconds)
    error_message = "lambda_async_failure_queue_message_retention_seconds must be an integer between 60 and 1209600."
  }
}

variable "lambda_async_maximum_retry_attempts" {
  description = "Maximum asynchronous retry attempts for Lambda invocations"
  type        = number
  default     = 2

  validation {
    condition     = var.lambda_async_maximum_retry_attempts >= 0 && var.lambda_async_maximum_retry_attempts <= 2 && var.lambda_async_maximum_retry_attempts == floor(var.lambda_async_maximum_retry_attempts)
    error_message = "lambda_async_maximum_retry_attempts must be an integer between 0 and 2."
  }
}

variable "lambda_async_max_event_age_seconds" {
  description = "Maximum age (seconds) for asynchronous Lambda events before they are discarded"
  type        = number
  default     = 3600

  validation {
    condition     = var.lambda_async_max_event_age_seconds >= 60 && var.lambda_async_max_event_age_seconds <= 21600 && var.lambda_async_max_event_age_seconds == floor(var.lambda_async_max_event_age_seconds)
    error_message = "lambda_async_max_event_age_seconds must be an integer between 60 and 21600."
  }
}

variable "stop_snapshot_wait_seconds" {
  description = "How long stop Lambda should wait for a newly-created daily RDS snapshot to become available before failing for retry"
  type        = number
  default     = 240

  validation {
    condition     = var.stop_snapshot_wait_seconds >= 30 && var.stop_snapshot_wait_seconds <= 840 && var.stop_snapshot_wait_seconds == floor(var.stop_snapshot_wait_seconds)
    error_message = "stop_snapshot_wait_seconds must be an integer between 30 and 840."
  }
}

variable "stop_snapshot_poll_interval_seconds" {
  description = "Polling interval while stop Lambda waits for RDS snapshot readiness"
  type        = number
  default     = 20

  validation {
    condition     = var.stop_snapshot_poll_interval_seconds >= 5 && var.stop_snapshot_poll_interval_seconds <= 120 && var.stop_snapshot_poll_interval_seconds == floor(var.stop_snapshot_poll_interval_seconds)
    error_message = "stop_snapshot_poll_interval_seconds must be an integer between 5 and 120."
  }
}

variable "cloudfront_api_max_attempts" {
  description = "Maximum retry attempts for CloudFront API calls in update-infra Lambda"
  type        = number
  default     = 5

  validation {
    condition     = var.cloudfront_api_max_attempts >= 1 && var.cloudfront_api_max_attempts <= 10 && var.cloudfront_api_max_attempts == floor(var.cloudfront_api_max_attempts)
    error_message = "cloudfront_api_max_attempts must be an integer between 1 and 10."
  }
}

variable "cloudfront_api_base_backoff_seconds" {
  description = "Base exponential backoff (seconds) for CloudFront API retries in update-infra Lambda"
  type        = number
  default     = 1

  validation {
    condition     = var.cloudfront_api_base_backoff_seconds >= 1 && var.cloudfront_api_base_backoff_seconds <= 30 && var.cloudfront_api_base_backoff_seconds == floor(var.cloudfront_api_base_backoff_seconds)
    error_message = "cloudfront_api_base_backoff_seconds must be an integer between 1 and 30."
  }
}

variable "cloudfront_api_max_backoff_seconds" {
  description = "Maximum backoff cap (seconds) for CloudFront API retries in update-infra Lambda"
  type        = number
  default     = 16

  validation {
    condition     = var.cloudfront_api_max_backoff_seconds >= 1 && var.cloudfront_api_max_backoff_seconds <= 120 && var.cloudfront_api_max_backoff_seconds == floor(var.cloudfront_api_max_backoff_seconds)
    error_message = "cloudfront_api_max_backoff_seconds must be an integer between 1 and 120."
  }
}

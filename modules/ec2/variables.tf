variable "ami_id" {
  description = "AMI ID for EC2"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.micro"
}

variable "key_name" {
  description = "Optional EC2 key pair name"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "List of public subnet IDs used by the ASG"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs attached to EC2 instances"
  type        = list(string)
}

variable "user_data_script" {
  description = "Script file for EC2 user data"
  type        = string
  default     = "your-user-data-script.sh"
}

variable "backend_port" {
  description = "Backend listener port exposed by the instance"
  type        = number
  default     = 8080
}

variable "enable_origin_auth_header" {
  description = "Enable CloudFront origin custom-header enforcement in default user-data script"
  type        = bool
  default     = true
}

variable "origin_auth_header_name" {
  description = "Primary origin auth header name used by default user-data script"
  type        = string
  default     = "X-Origin-Verify"
}

variable "origin_auth_header_value" {
  description = "Primary origin auth header value used by default user-data script"
  type        = string
  default     = ""
  sensitive   = true
}

variable "origin_auth_previous_header_name" {
  description = "Secondary origin auth header name for secret rotation"
  type        = string
  default     = "X-Origin-Verify-Prev"
}

variable "origin_auth_previous_header_value" {
  description = "Secondary origin auth header value for secret rotation"
  type        = string
  default     = ""
  sensitive   = true
}

variable "rds_endpoint" {
  description = "RDS endpoint injected into user data"
  type        = string
}

variable "rds_username" {
  description = "RDS username injected into user data"
  type        = string
  default     = ""
}

variable "rds_password" {
  description = "RDS password injected into user data"
  type        = string
  default     = ""
  sensitive   = true
}

variable "db_name" {
  description = "Database name injected into user data"
  type        = string
  default     = ""
}

variable "iam_instance_profile" {
  description = "IAM instance profile name"
  type        = string
}

variable "launch_template_prefix" {
  description = "Launch template name prefix"
  type        = string
  default     = "ecoauto-backend-lt-"
}

variable "ec2_instance_name" {
  description = "Name tag for EC2 instances"
  type        = string
  default     = "ecoauto-backend"
}

variable "asg_name" {
  description = "Auto Scaling Group name"
  type        = string
  default     = "ecoauto-backend-asg"
}

variable "desired_capacity" {
  description = "Desired number of instances"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
  default     = 1
}

variable "cpu_target_value" {
  description = "Target CPU utilization for ASG"
  type        = number
  default     = 70
}

variable "asg_health_check_grace_period" {
  description = "Health check grace period (seconds) for ASG EC2 health checks"
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

variable "enable_instance_refresh" {
  description = "Enable rolling instance refresh when launch template changes"
  type        = bool
  default     = true
}

variable "instance_refresh_min_healthy_pct" {
  description = "Minimum healthy instance percentage during rolling instance refresh"
  type        = number
  default     = 50

  validation {
    condition     = var.instance_refresh_min_healthy_pct >= 0 && var.instance_refresh_min_healthy_pct <= 100 && var.instance_refresh_min_healthy_pct == floor(var.instance_refresh_min_healthy_pct)
    error_message = "instance_refresh_min_healthy_pct must be an integer between 0 and 100."
  }
}

variable "instance_refresh_warmup_seconds" {
  description = "Warmup time (seconds) per refresh batch"
  type        = number
  default     = 180

  validation {
    condition     = var.instance_refresh_warmup_seconds >= 0 && var.instance_refresh_warmup_seconds <= 7200 && var.instance_refresh_warmup_seconds == floor(var.instance_refresh_warmup_seconds)
    error_message = "instance_refresh_warmup_seconds must be an integer between 0 and 7200."
  }
}

variable "enable_workspace_suffix" {
  description = "Suffix names/tags with Terraform workspace"
  type        = bool
  default     = false
}

variable "root_block_device_name" {
  description = "Root block device name for launch template"
  type        = string
  default     = "/dev/xvda"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Root EBS volume type"
  type        = string
  default     = "gp3"
}

variable "ebs_kms_key_id" {
  description = "Optional KMS key ID/ARN for EC2 root volume encryption"
  type        = string
  default     = null
}

variable "infra_update_lambda_role_arn" {
  type = string
}

variable "scheduler_lambda_role_arn" {
  type = string
}

variable "lambda_edge_role_arn" {
  type = string
}

variable "asg_name" {
  type = string
}

variable "rds_instance_id" {
  type = string
}

variable "backend_cf_dist_id" {
  type = string
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "origin_protocol_policy" {
  type    = string
  default = "http-only"
}

variable "enable_origin_auth_header" {
  type    = bool
  default = true
}

variable "origin_auth_header_name" {
  type    = string
  default = "X-Origin-Verify"
}

variable "origin_auth_header_value" {
  type      = string
  default   = ""
  sensitive = true
}

variable "origin_auth_previous_header_name" {
  type    = string
  default = "X-Origin-Verify-Prev"
}

variable "origin_auth_previous_header_value" {
  type      = string
  default   = ""
  sensitive = true
}

variable "enable_origin_health_probe" {
  type    = bool
  default = false
}

variable "origin_health_fail_open" {
  type    = bool
  default = true
}

variable "origin_health_path" {
  type    = string
  default = "/health"
}

variable "origin_health_timeout_seconds" {
  type    = number
  default = 2
}

variable "max_origins" {
  type    = number
  default = 20
}

variable "start_min_size" {
  type    = number
  default = 1
}

variable "start_desired_capacity" {
  type    = number
  default = 1
}

variable "start_max_size" {
  type    = number
  default = 2
}

variable "stop_snapshot_wait_seconds" {
  type    = number
  default = 240

  validation {
    condition     = var.stop_snapshot_wait_seconds >= 30 && var.stop_snapshot_wait_seconds <= 840 && var.stop_snapshot_wait_seconds == floor(var.stop_snapshot_wait_seconds)
    error_message = "stop_snapshot_wait_seconds must be an integer between 30 and 840."
  }
}

variable "stop_snapshot_poll_interval_seconds" {
  type    = number
  default = 20

  validation {
    condition     = var.stop_snapshot_poll_interval_seconds >= 5 && var.stop_snapshot_poll_interval_seconds <= 120 && var.stop_snapshot_poll_interval_seconds == floor(var.stop_snapshot_poll_interval_seconds)
    error_message = "stop_snapshot_poll_interval_seconds must be an integer between 5 and 120."
  }
}

variable "enable_workspace_suffix" {
  type    = bool
  default = false
}

variable "enable_snapshot_cleanup" {
  type    = bool
  default = false
}

variable "snapshot_retention_days" {
  type    = number
  default = 14
}

variable "snapshot_min_keep_count" {
  type    = number
  default = 3
}

variable "lambda_log_retention_days" {
  type    = number
  default = 30
}

variable "lambda_log_kms_key_id" {
  type    = string
  default = null
}

variable "manage_lambda_log_groups" {
  type    = bool
  default = true
}

variable "update_infra_reserved_concurrent_executions" {
  type    = number
  default = 1
}

variable "enable_xray_tracing" {
  type    = bool
  default = true
}

variable "enable_async_failure_queue" {
  type    = bool
  default = true
}

variable "async_failure_queue_message_retention_seconds" {
  type    = number
  default = 1209600
}

variable "lambda_async_maximum_retry_attempts" {
  type    = number
  default = 2
}

variable "lambda_async_max_event_age_seconds" {
  type    = number
  default = 3600
}

variable "cloudfront_api_max_attempts" {
  type    = number
  default = 5
}

variable "cloudfront_api_base_backoff_seconds" {
  type    = number
  default = 1
}

variable "cloudfront_api_max_backoff_seconds" {
  type    = number
  default = 16
}

variable "enable_update_infra_alarm" {
  type    = bool
  default = true
}

variable "update_infra_alarm_actions" {
  type    = list(string)
  default = []
}

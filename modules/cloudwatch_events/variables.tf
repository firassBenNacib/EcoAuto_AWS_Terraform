variable "start_lambda_arn" {
  type = string
}

variable "stop_lambda_arn" {
  type = string
}

variable "infra_update_lambda_arn" {
  type = string
}

variable "delete_old_snapshots_arn" {
  type    = string
  default = null
}

variable "asg_name" {
  type = string
}

variable "enable_start_stop_schedule" {
  type    = bool
  default = true
}

variable "start_schedule_expression" {
  type    = string
  default = "cron(0 7 * * ? *)"
}

variable "stop_schedule_expression" {
  type    = string
  default = "cron(0 1 * * ? *)"
}

variable "snapshot_cleanup_schedule_expression" {
  type    = string
  default = "cron(0 22 * * ? *)"
}

variable "enable_snapshot_cleanup" {
  type    = bool
  default = false
}

variable "dead_letter_queue_arn" {
  description = "Optional SQS queue ARN used as EventBridge target dead-letter queue"
  type        = string
  default     = null
}

variable "lambda_invoke_retry_attempts" {
  description = "Maximum EventBridge retry attempts for Lambda targets"
  type        = number
  default     = 6

  validation {
    condition     = var.lambda_invoke_retry_attempts >= 0 && var.lambda_invoke_retry_attempts <= 185 && var.lambda_invoke_retry_attempts == floor(var.lambda_invoke_retry_attempts)
    error_message = "lambda_invoke_retry_attempts must be an integer between 0 and 185."
  }
}

variable "lambda_invoke_max_event_age_seconds" {
  description = "Maximum EventBridge event age (seconds) for Lambda target retries"
  type        = number
  default     = 3600

  validation {
    condition     = var.lambda_invoke_max_event_age_seconds >= 60 && var.lambda_invoke_max_event_age_seconds <= 86400 && var.lambda_invoke_max_event_age_seconds == floor(var.lambda_invoke_max_event_age_seconds)
    error_message = "lambda_invoke_max_event_age_seconds must be an integer between 60 and 86400."
  }
}

variable "stop_lambda_invoke_retry_attempts" {
  description = "Optional override for EventBridge retry attempts used only by the stop-resources target"
  type        = number
  default     = null

  validation {
    condition = (
      var.stop_lambda_invoke_retry_attempts == null ||
      (
        var.stop_lambda_invoke_retry_attempts >= 0 &&
        var.stop_lambda_invoke_retry_attempts <= 185 &&
        var.stop_lambda_invoke_retry_attempts == floor(var.stop_lambda_invoke_retry_attempts)
      )
    )
    error_message = "stop_lambda_invoke_retry_attempts must be null or an integer between 0 and 185."
  }
}

variable "stop_lambda_invoke_max_event_age_seconds" {
  description = "Optional override for EventBridge max event age (seconds) used only by the stop-resources target"
  type        = number
  default     = null

  validation {
    condition = (
      var.stop_lambda_invoke_max_event_age_seconds == null ||
      (
        var.stop_lambda_invoke_max_event_age_seconds >= 60 &&
        var.stop_lambda_invoke_max_event_age_seconds <= 86400 &&
        var.stop_lambda_invoke_max_event_age_seconds == floor(var.stop_lambda_invoke_max_event_age_seconds)
      )
    )
    error_message = "stop_lambda_invoke_max_event_age_seconds must be null or an integer between 60 and 86400."
  }
}

variable "enable_origin_health_probe" {
  type    = bool
  default = false
}

variable "origin_health_interval_minutes" {
  type    = number
  default = 5

  validation {
    condition     = var.origin_health_interval_minutes >= 1 && var.origin_health_interval_minutes == floor(var.origin_health_interval_minutes)
    error_message = "origin_health_interval_minutes must be an integer >= 1."
  }
}

variable "enable_workspace_suffix" {
  type    = bool
  default = false
}

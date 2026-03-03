terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  workspace                     = terraform.workspace
  update_infra_function_name    = var.enable_workspace_suffix ? "UpdateInfra-${local.workspace}" : "UpdateInfraRouting"
  start_function_name           = var.enable_workspace_suffix ? "StartEC2RDS-${local.workspace}" : "StartComputeResources"
  stop_function_name            = var.enable_workspace_suffix ? "StopEC2RDS-${local.workspace}" : "StopComputeResources"
  delete_function_name          = var.enable_workspace_suffix ? "DeleteSnapshots-${local.workspace}" : "DeleteSnapshots"
  edge_function_name            = var.enable_workspace_suffix ? "EdgeOriginSelector-${local.workspace}" : "EdgeOriginSelector"
  async_failure_queue_name      = var.enable_workspace_suffix ? "lambda-async-failures-${local.workspace}" : "lambda-async-failures"
  scheduler_lambda_role_name    = element(reverse(split("/", var.scheduler_lambda_role_arn)), 0)
  infra_update_lambda_role_name = element(reverse(split("/", var.infra_update_lambda_role_arn)), 0)
}

data "archive_file" "update_infra_zip" {
  type        = "zip"
  source_file = "${path.module}/src/update_infra.py"
  output_path = "${path.module}/src/update_infra.zip"
}

data "archive_file" "start_instances_zip" {
  type        = "zip"
  source_file = "${path.module}/src/start_instances.py"
  output_path = "${path.module}/src/start_instances.zip"
}

data "archive_file" "stop_instances_zip" {
  type        = "zip"
  source_file = "${path.module}/src/stop_instances.py"
  output_path = "${path.module}/src/stop_instances.zip"
}

data "archive_file" "edge_selector_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src/edge_origin_selector"
  output_path = "${path.module}/src/edge_origin_selector.zip"
}

data "archive_file" "delete_old_snapshots_zip" {
  type        = "zip"
  source_file = "${path.module}/src/delete_old_snapshots.py"
  output_path = "${path.module}/src/delete_old_snapshots.zip"
}

resource "aws_sqs_queue" "async_failure" {
  count = var.enable_async_failure_queue ? 1 : 0

  name                      = local.async_failure_queue_name
  message_retention_seconds = var.async_failure_queue_message_retention_seconds
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue_policy" "async_failure" {
  count = var.enable_async_failure_queue ? 1 : 0

  queue_url = aws_sqs_queue.async_failure[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaServiceFromSameAccount"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.async_failure[0].arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AllowEventBridgeServiceFromSameAccount"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.async_failure[0].arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "scheduler_async_failure_queue_send" {
  count = var.enable_async_failure_queue ? 1 : 0

  name = "${local.scheduler_lambda_role_name}-async-failure-send"
  role = local.scheduler_lambda_role_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.async_failure[0].arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "infra_update_async_failure_queue_send" {
  count = var.enable_async_failure_queue ? 1 : 0

  name = "${local.infra_update_lambda_role_name}-async-failure-send"
  role = local.infra_update_lambda_role_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.async_failure[0].arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "update_infra" {
  count = var.manage_lambda_log_groups ? 1 : 0

  name              = "/aws/lambda/${local.update_infra_function_name}"
  retention_in_days = var.lambda_log_retention_days
  kms_key_id        = var.lambda_log_kms_key_id
}

resource "aws_cloudwatch_log_group" "start_instances" {
  name              = "/aws/lambda/${local.start_function_name}"
  retention_in_days = var.lambda_log_retention_days
  kms_key_id        = var.lambda_log_kms_key_id
}

resource "aws_cloudwatch_log_group" "stop_instances" {
  count = var.manage_lambda_log_groups ? 1 : 0

  name              = "/aws/lambda/${local.stop_function_name}"
  retention_in_days = var.lambda_log_retention_days
  kms_key_id        = var.lambda_log_kms_key_id
}

resource "aws_cloudwatch_log_group" "delete_old_snapshots" {
  count = var.manage_lambda_log_groups && var.enable_snapshot_cleanup ? 1 : 0

  name              = "/aws/lambda/${local.delete_function_name}"
  retention_in_days = var.lambda_log_retention_days
  kms_key_id        = var.lambda_log_kms_key_id
}

resource "aws_lambda_function" "update_infra" {
  filename                       = data.archive_file.update_infra_zip.output_path
  function_name                  = local.update_infra_function_name
  handler                        = "update_infra.lambda_handler"
  runtime                        = "python3.12"
  role                           = var.infra_update_lambda_role_arn
  source_code_hash               = data.archive_file.update_infra_zip.output_base64sha256
  timeout                        = 60
  reserved_concurrent_executions = var.update_infra_reserved_concurrent_executions
  depends_on                     = [aws_cloudwatch_log_group.update_infra]

  environment {
    variables = {
      CLOUDFRONT_DIST_ID                  = var.backend_cf_dist_id
      ASG_NAME                            = var.asg_name
      BACKEND_PORT                        = tostring(var.app_port)
      ORIGIN_PROTOCOL_POLICY              = var.origin_protocol_policy
      ENABLE_ORIGIN_AUTH_HEADER           = tostring(var.enable_origin_auth_header)
      ORIGIN_AUTH_HEADER_NAME             = var.origin_auth_header_name
      ORIGIN_AUTH_HEADER_VALUE            = var.origin_auth_header_value
      ORIGIN_AUTH_PREVIOUS_HEADER_NAME    = var.origin_auth_previous_header_name
      ORIGIN_AUTH_PREVIOUS_HEADER_VALUE   = var.origin_auth_previous_header_value
      ENABLE_ORIGIN_HEALTH_PROBE          = tostring(var.enable_origin_health_probe)
      ORIGIN_HEALTH_FAIL_OPEN             = tostring(var.origin_health_fail_open)
      ORIGIN_HEALTH_PATH                  = var.origin_health_path
      ORIGIN_HEALTH_TIMEOUT_SECONDS       = tostring(var.origin_health_timeout_seconds)
      CLOUDFRONT_API_MAX_ATTEMPTS         = tostring(var.cloudfront_api_max_attempts)
      CLOUDFRONT_API_BASE_BACKOFF_SECONDS = tostring(var.cloudfront_api_base_backoff_seconds)
      CLOUDFRONT_API_MAX_BACKOFF_SECONDS  = tostring(var.cloudfront_api_max_backoff_seconds)
      MAX_ORIGINS                         = tostring(var.max_origins)
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.enable_async_failure_queue ? [1] : []
    content {
      target_arn = aws_sqs_queue.async_failure[0].arn
    }
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }
}

resource "aws_lambda_function" "start_instances" {
  filename         = data.archive_file.start_instances_zip.output_path
  function_name    = local.start_function_name
  handler          = "start_instances.lambda_handler"
  runtime          = "python3.12"
  role             = var.scheduler_lambda_role_arn
  source_code_hash = data.archive_file.start_instances_zip.output_base64sha256
  timeout          = 60
  depends_on       = [aws_cloudwatch_log_group.start_instances]

  environment {
    variables = {
      ASG_NAME               = var.asg_name
      RDS_INSTANCE_ID        = var.rds_instance_id
      START_MIN_SIZE         = tostring(var.start_min_size)
      START_DESIRED_CAPACITY = tostring(var.start_desired_capacity)
      START_MAX_SIZE         = tostring(var.start_max_size)
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.enable_async_failure_queue ? [1] : []
    content {
      target_arn = aws_sqs_queue.async_failure[0].arn
    }
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }
}

resource "aws_lambda_function" "stop_instances" {
  filename         = data.archive_file.stop_instances_zip.output_path
  function_name    = local.stop_function_name
  handler          = "stop_instances.lambda_handler"
  runtime          = "python3.12"
  role             = var.scheduler_lambda_role_arn
  source_code_hash = data.archive_file.stop_instances_zip.output_base64sha256
  timeout          = 300
  depends_on       = [aws_cloudwatch_log_group.stop_instances]

  environment {
    variables = {
      ASG_NAME                            = var.asg_name
      RDS_INSTANCE_ID                     = var.rds_instance_id
      STOP_SNAPSHOT_WAIT_SECONDS          = tostring(var.stop_snapshot_wait_seconds)
      STOP_SNAPSHOT_POLL_INTERVAL_SECONDS = tostring(var.stop_snapshot_poll_interval_seconds)
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.enable_async_failure_queue ? [1] : []
    content {
      target_arn = aws_sqs_queue.async_failure[0].arn
    }
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }
}

resource "aws_lambda_function" "delete_old_snapshots" {
  count = var.enable_snapshot_cleanup ? 1 : 0

  filename         = data.archive_file.delete_old_snapshots_zip.output_path
  function_name    = local.delete_function_name
  handler          = "delete_old_snapshots.lambda_handler"
  runtime          = "python3.12"
  role             = var.scheduler_lambda_role_arn
  source_code_hash = data.archive_file.delete_old_snapshots_zip.output_base64sha256
  timeout          = 60
  depends_on       = [aws_cloudwatch_log_group.delete_old_snapshots]

  environment {
    variables = {
      RDS_INSTANCE_ID         = var.rds_instance_id
      SNAPSHOT_RETENTION_DAYS = tostring(var.snapshot_retention_days)
      SNAPSHOT_MIN_KEEP_COUNT = tostring(var.snapshot_min_keep_count)
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.enable_async_failure_queue ? [1] : []
    content {
      target_arn = aws_sqs_queue.async_failure[0].arn
    }
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }
}

resource "aws_lambda_function_event_invoke_config" "update_infra" {
  count = var.enable_async_failure_queue ? 1 : 0

  function_name                = aws_lambda_function.update_infra.function_name
  maximum_retry_attempts       = var.lambda_async_maximum_retry_attempts
  maximum_event_age_in_seconds = var.lambda_async_max_event_age_seconds

  destination_config {
    on_failure {
      destination = aws_sqs_queue.async_failure[0].arn
    }
  }
}

resource "aws_lambda_function_event_invoke_config" "start_instances" {
  count = var.enable_async_failure_queue ? 1 : 0

  function_name                = aws_lambda_function.start_instances.function_name
  maximum_retry_attempts       = var.lambda_async_maximum_retry_attempts
  maximum_event_age_in_seconds = var.lambda_async_max_event_age_seconds

  destination_config {
    on_failure {
      destination = aws_sqs_queue.async_failure[0].arn
    }
  }
}

resource "aws_lambda_function_event_invoke_config" "stop_instances" {
  count = var.enable_async_failure_queue ? 1 : 0

  function_name                = aws_lambda_function.stop_instances.function_name
  maximum_retry_attempts       = var.lambda_async_maximum_retry_attempts
  maximum_event_age_in_seconds = var.lambda_async_max_event_age_seconds

  destination_config {
    on_failure {
      destination = aws_sqs_queue.async_failure[0].arn
    }
  }
}

resource "aws_lambda_function_event_invoke_config" "delete_old_snapshots" {
  count = var.enable_async_failure_queue && var.enable_snapshot_cleanup ? 1 : 0

  function_name                = aws_lambda_function.delete_old_snapshots[0].function_name
  maximum_retry_attempts       = var.lambda_async_maximum_retry_attempts
  maximum_event_age_in_seconds = var.lambda_async_max_event_age_seconds

  destination_config {
    on_failure {
      destination = aws_sqs_queue.async_failure[0].arn
    }
  }
}

resource "aws_cloudwatch_log_group" "edge_selector" {
  provider = aws.us_east_1

  name              = "/aws/lambda/${local.edge_function_name}"
  retention_in_days = var.lambda_log_retention_days
  kms_key_id        = var.lambda_log_kms_key_id
}

#tfsec:ignore:aws-lambda-enable-tracing Lambda@Edge tracing support is limited; tracing is enabled on regional Lambdas.
resource "aws_lambda_function" "lambda_edge_selector" {
  provider         = aws.us_east_1
  function_name    = local.edge_function_name
  filename         = data.archive_file.edge_selector_zip.output_path
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  role             = var.lambda_edge_role_arn
  publish          = true
  source_code_hash = data.archive_file.edge_selector_zip.output_base64sha256
  depends_on       = [aws_cloudwatch_log_group.edge_selector]

  timeouts {
    delete = "30m"
  }
}

resource "aws_cloudwatch_metric_alarm" "update_infra_errors" {
  count = var.enable_update_infra_alarm ? 1 : 0

  alarm_name          = "${local.update_infra_function_name}-Errors"
  alarm_description   = "Alarm when update-infra Lambda returns one or more errors in a 5-minute period."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.update_infra_alarm_actions
  ok_actions          = var.update_infra_alarm_actions

  dimensions = {
    FunctionName = aws_lambda_function.update_infra.function_name
  }
}

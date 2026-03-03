locals {
  workspace = terraform.workspace

  start_rule_name            = var.enable_workspace_suffix ? "StartEC2AndRDSRule-${local.workspace}" : "StartComputeResourcesRule"
  stop_rule_name             = var.enable_workspace_suffix ? "StopEC2AndRDSRule-${local.workspace}" : "StopComputeResourcesRule"
  asg_trigger_rule_name      = var.enable_workspace_suffix ? "AsgInstanceChangeTrigger-${local.workspace}" : "AsgInstanceChangeTrigger"
  health_probe_rule_name     = var.enable_workspace_suffix ? "OriginHealthProbe-${local.workspace}" : "OriginHealthProbe"
  snapshot_cleanup_rule_name = var.enable_workspace_suffix ? "DailyRDSSnapshotCleanup-${local.workspace}" : "DailyRDSSnapshotCleanup"

  health_probe_schedule_expression = format(
    "rate(%d minute%s)",
    var.origin_health_interval_minutes,
    var.origin_health_interval_minutes == 1 ? "" : "s"
  )

  effective_stop_lambda_invoke_retry_attempts = (
    var.stop_lambda_invoke_retry_attempts != null ?
    var.stop_lambda_invoke_retry_attempts :
    var.lambda_invoke_retry_attempts
  )

  effective_stop_lambda_invoke_max_event_age_seconds = (
    var.stop_lambda_invoke_max_event_age_seconds != null ?
    var.stop_lambda_invoke_max_event_age_seconds :
    var.lambda_invoke_max_event_age_seconds
  )
}

resource "aws_cloudwatch_event_rule" "start_schedule" {
  count = var.enable_start_stop_schedule ? 1 : 0

  name                = local.start_rule_name
  schedule_expression = var.start_schedule_expression
}

resource "aws_cloudwatch_event_target" "start_target" {
  count = var.enable_start_stop_schedule ? 1 : 0

  rule      = aws_cloudwatch_event_rule.start_schedule[0].name
  target_id = "StartResources"
  arn       = var.start_lambda_arn

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_queue_arn != null ? [1] : []
    content {
      arn = var.dead_letter_queue_arn
    }
  }

  retry_policy {
    maximum_retry_attempts       = var.lambda_invoke_retry_attempts
    maximum_event_age_in_seconds = var.lambda_invoke_max_event_age_seconds
  }
}

resource "aws_lambda_permission" "allow_eventbridge_start" {
  count = var.enable_start_stop_schedule ? 1 : 0

  statement_id  = var.enable_workspace_suffix ? "AllowExecutionFromEventBridgeStart-${local.workspace}" : "AllowExecutionFromEventBridgeStart"
  action        = "lambda:InvokeFunction"
  function_name = var.start_lambda_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_schedule[0].arn
}

resource "aws_cloudwatch_event_rule" "stop_schedule" {
  count = var.enable_start_stop_schedule ? 1 : 0

  name                = local.stop_rule_name
  schedule_expression = var.stop_schedule_expression
}

resource "aws_cloudwatch_event_target" "stop_target" {
  count = var.enable_start_stop_schedule ? 1 : 0

  rule      = aws_cloudwatch_event_rule.stop_schedule[0].name
  target_id = "StopResources"
  arn       = var.stop_lambda_arn

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_queue_arn != null ? [1] : []
    content {
      arn = var.dead_letter_queue_arn
    }
  }

  retry_policy {
    maximum_retry_attempts       = local.effective_stop_lambda_invoke_retry_attempts
    maximum_event_age_in_seconds = local.effective_stop_lambda_invoke_max_event_age_seconds
  }
}

resource "aws_lambda_permission" "allow_eventbridge_stop" {
  count = var.enable_start_stop_schedule ? 1 : 0

  statement_id  = var.enable_workspace_suffix ? "AllowExecutionFromEventBridgeStop-${local.workspace}" : "AllowExecutionFromEventBridgeStop"
  action        = "lambda:InvokeFunction"
  function_name = var.stop_lambda_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_schedule[0].arn
}

resource "aws_cloudwatch_event_rule" "asg_instance_state" {
  name        = local.asg_trigger_rule_name
  description = "Trigger backend infra update on launch/terminate events for the target ASG"

  event_pattern = jsonencode({
    source = ["aws.autoscaling"]
    "detail-type" = [
      "EC2 Instance Launch Successful",
      "EC2 Instance Terminate Successful"
    ]
    detail = {
      AutoScalingGroupName = [var.asg_name]
    }
  })
}

resource "aws_cloudwatch_event_target" "trigger_lambda_on_asg_change" {
  rule      = aws_cloudwatch_event_rule.asg_instance_state.name
  target_id = "InvokeUpdateInfraLambda"
  arn       = var.infra_update_lambda_arn

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_queue_arn != null ? [1] : []
    content {
      arn = var.dead_letter_queue_arn
    }
  }

  retry_policy {
    maximum_retry_attempts       = var.lambda_invoke_retry_attempts
    maximum_event_age_in_seconds = var.lambda_invoke_max_event_age_seconds
  }
}

resource "aws_lambda_permission" "allow_asg_change_update_infra" {
  statement_id  = var.enable_workspace_suffix ? "AllowAsgChangeToUpdateInfra-${local.workspace}" : "AllowAsgChangeToUpdateInfra"
  action        = "lambda:InvokeFunction"
  function_name = var.infra_update_lambda_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.asg_instance_state.arn
}

resource "aws_cloudwatch_event_rule" "origin_health_probe" {
  count = var.enable_origin_health_probe ? 1 : 0

  name                = local.health_probe_rule_name
  schedule_expression = local.health_probe_schedule_expression
}

resource "aws_cloudwatch_event_target" "origin_health_probe_target" {
  count = var.enable_origin_health_probe ? 1 : 0

  rule      = aws_cloudwatch_event_rule.origin_health_probe[0].name
  target_id = "InvokeUpdateInfraHealthProbe"
  arn       = var.infra_update_lambda_arn

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_queue_arn != null ? [1] : []
    content {
      arn = var.dead_letter_queue_arn
    }
  }

  retry_policy {
    maximum_retry_attempts       = var.lambda_invoke_retry_attempts
    maximum_event_age_in_seconds = var.lambda_invoke_max_event_age_seconds
  }
}

resource "aws_lambda_permission" "allow_origin_health_probe_update_infra" {
  count = var.enable_origin_health_probe ? 1 : 0

  statement_id  = var.enable_workspace_suffix ? "AllowOriginHealthProbeToUpdateInfra-${local.workspace}" : "AllowOriginHealthProbeToUpdateInfra"
  action        = "lambda:InvokeFunction"
  function_name = var.infra_update_lambda_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.origin_health_probe[0].arn
}

resource "aws_cloudwatch_event_rule" "cleanup_snapshots" {
  count = var.enable_snapshot_cleanup ? 1 : 0

  name                = local.snapshot_cleanup_rule_name
  schedule_expression = var.snapshot_cleanup_schedule_expression
}

resource "aws_cloudwatch_event_target" "cleanup_snapshots_target" {
  count = var.enable_snapshot_cleanup ? 1 : 0

  rule      = aws_cloudwatch_event_rule.cleanup_snapshots[0].name
  target_id = "DeleteOldRDSSnapshots"
  arn       = var.delete_old_snapshots_arn

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_queue_arn != null ? [1] : []
    content {
      arn = var.dead_letter_queue_arn
    }
  }

  retry_policy {
    maximum_retry_attempts       = var.lambda_invoke_retry_attempts
    maximum_event_age_in_seconds = var.lambda_invoke_max_event_age_seconds
  }
}

resource "aws_lambda_permission" "allow_cleanup_snapshots" {
  count = var.enable_snapshot_cleanup ? 1 : 0

  statement_id  = var.enable_workspace_suffix ? "AllowEventBridgeSnapshotCleanup-${local.workspace}" : "AllowEventBridgeSnapshotCleanup"
  action        = "lambda:InvokeFunction"
  function_name = var.delete_old_snapshots_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cleanup_snapshots[0].arn
}

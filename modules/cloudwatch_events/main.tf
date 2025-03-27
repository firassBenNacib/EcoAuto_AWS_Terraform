resource "aws_cloudwatch_event_rule" "start_schedule" {
  name                = "StartComputeResourcesRule"
  schedule_expression = "cron(0 7 * * ? *)"
}

resource "aws_cloudwatch_event_target" "start_target" {
  rule      = aws_cloudwatch_event_rule.start_schedule.name
  target_id = "StartResources"
  arn       = var.start_lambda_arn
}

resource "aws_lambda_permission" "allow_eventbridge_start" {
  statement_id  = "AllowExecutionFromEventBridgeStart"
  action        = "lambda:InvokeFunction"
  function_name = var.start_lambda_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_schedule.arn
}

resource "aws_cloudwatch_event_rule" "stop_schedule" {
  name                = "StopComputeResourcesRule"
  schedule_expression = "cron(0 1 * * ? *)"
}

resource "aws_cloudwatch_event_target" "stop_target" {
  rule      = aws_cloudwatch_event_rule.stop_schedule.name
  target_id = "StopResources"
  arn       = var.stop_lambda_arn
}

resource "aws_lambda_permission" "allow_eventbridge_stop" {
  statement_id  = "AllowExecutionFromEventBridgeStop"
  action        = "lambda:InvokeFunction"
  function_name = var.stop_lambda_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_schedule.arn
}

resource "aws_cloudwatch_event_rule" "compute_running_state" {
  name        = "ComputeStartTrigger"
  description = "Trigger Lambda on compute resource starting"
  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"],
    "detail" : {
      "state" : ["running"]
    }
  })
}

resource "aws_cloudwatch_event_target" "trigger_lambda_on_running_infra" {
  rule      = aws_cloudwatch_event_rule.compute_running_state.name
  target_id = "InvokeUpdateInfraLambda"
  arn       = var.infra_update_lambda_arn
}

resource "aws_lambda_permission" "allow_compute_running_update_infra" {
  statement_id  = "AllowComputeRunningToUpdateInfra"
  action        = "lambda:InvokeFunction"
  function_name = var.infra_update_lambda_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.compute_running_state.arn
}

resource "aws_cloudwatch_event_target" "trigger_lambda_on_running_sgs" {
  rule      = aws_cloudwatch_event_rule.compute_running_state.name
  target_id = "InvokeUpdateSecurityGroupsLambda"
  arn       = var.update_sgs_lambda_arn
}

resource "aws_lambda_permission" "allow_compute_running_update_sgs" {
  statement_id  = "AllowComputeRunningToUpdateSGs"
  action        = "lambda:InvokeFunction"
  function_name = var.update_sgs_lambda_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.compute_running_state.arn
}

resource "aws_cloudwatch_event_rule" "compute_termination_state" {
  name        = "ComputeTerminationTrigger"
  description = "Trigger Lambda on compute resource termination"
  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["EC2 Instance State-change Notification"],
    "detail" : {
      "state" : ["shutting-down", "terminated"]
    }
  })
}

resource "aws_cloudwatch_event_target" "trigger_lambda_on_termination" {
  rule      = aws_cloudwatch_event_rule.compute_termination_state.name
  target_id = "InvokeUpdateInfraOnTermination"
  arn       = var.infra_update_lambda_arn
}

resource "aws_lambda_permission" "allow_compute_termination_update_infra" {
  statement_id  = "AllowComputeTerminationToUpdateInfra"
  action        = "lambda:InvokeFunction"
  function_name = var.infra_update_lambda_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.compute_termination_state.arn
}

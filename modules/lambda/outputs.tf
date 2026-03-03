output "update_infra_lambda_arn" {
  value = aws_lambda_function.update_infra.arn
}

output "start_lambda_arn" {
  value = aws_lambda_function.start_instances.arn
}

output "stop_lambda_arn" {
  value = aws_lambda_function.stop_instances.arn
}

output "lambda_edge_selector_arn" {
  value = aws_lambda_function.lambda_edge_selector.qualified_arn
}

output "update_infra_lambda_name" {
  value = aws_lambda_function.update_infra.function_name
}

output "delete_old_snapshots_arn" {
  value = try(aws_lambda_function.delete_old_snapshots[0].arn, null)
}

output "update_infra_error_alarm_name" {
  value = try(aws_cloudwatch_metric_alarm.update_infra_errors[0].alarm_name, null)
}

output "async_failure_queue_arn" {
  value = try(aws_sqs_queue.async_failure[0].arn, null)
}

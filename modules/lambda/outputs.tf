output "update_sgs_lambda_arn" {
  value = aws_lambda_function.update_sgs.arn
}

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

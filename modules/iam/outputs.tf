
output "ec2_instance_profile_name" {
  value = aws_iam_instance_profile.ec2_basic_profile.name
}

output "lambda_sg_update_role_arn" {
  value = aws_iam_role.lambda_sg_update_role.arn
}

output "lambda_edge_role_arn" {
  value = aws_iam_role.lambda_edge_role.arn
}

output "scheduler_lambda_role_arn" {
  value = aws_iam_role.scheduler_lambda_role.arn
}

output "infra_update_lambda_role_arn" {
  value = aws_iam_role.infra_update_lambda_role.arn
}
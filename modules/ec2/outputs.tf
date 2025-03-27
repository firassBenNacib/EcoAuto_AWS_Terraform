output "asg_name" {
  description = "Auto Scaling Group Name"
  value       = aws_autoscaling_group.this.name
}

output "launch_template_id" {
  description = "Launch Template ID"
  value       = aws_launch_template.this.id
}

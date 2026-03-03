output "endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.this.endpoint
}

output "instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.this.id
}

output "db_subnet_group_name" {
  description = "RDS DB subnet group name"
  value       = aws_db_subnet_group.this.name
}

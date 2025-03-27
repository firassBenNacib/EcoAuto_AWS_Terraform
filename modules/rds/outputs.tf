output "endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.this.endpoint
}

output "instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.this.id
}


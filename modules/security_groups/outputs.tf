output "cloudfront_sg_ids" {
  description = "List of CloudFront Security Group IDs"
  value       = aws_security_group.cloudfront_sg[*].id
}

output "ec2_rds_sg_id" {
  description = "Security Group ID for EC2 to RDS communication"
  value       = aws_security_group.ec2_rds_sg.id
}

output "rds_ec2_sg_id" {
  description = "Security Group ID for RDS to EC2 communication"
  value       = aws_security_group.rds_ec2_sg.id
}

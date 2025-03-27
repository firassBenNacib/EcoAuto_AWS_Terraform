

variable "ec2_ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
  default     = "your_ami_id"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.micro"
}

variable "ec2_key_name" {
  description = "Key pair name for EC2"
  type        = string
  default     = "your-key-name"
}

variable "acm_cert_backend" {
  description = "ACM Certificate ARN for backend CloudFront"
  type        = string
  default     = "arn:aws:acm:us-east-1:your-account-id:certificate/your-backend-certificate-id"
}

variable "acm_cert_frontend" {
  description = "ACM Certificate ARN for frontend CloudFront"
  type        = string
  default     = "arn:aws:acm:us-east-1:your-account-id:certificate/your-frontend-certificate-id"

}

variable "rds_username" {
  description = "RDS master username"
  type        = string
}

variable "rds_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "kms_key_id" {
  description = "KMS Key ID for RDS encryption"
  type        = string
  default     = "arn:aws:kms:region:your-account-id:key/your-key-id"
}

variable "route53_zone_id" {
  description = "Route 53 Hosted Zone ID"
  type        = string
  default     = "your-route53-zone-id"
}

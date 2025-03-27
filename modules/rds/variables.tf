variable "identifier" {
  description = "RDS instance identifier"
  type        = string
  default     = "your-rds-instance-id"
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "username" {
  description = "Master username"
  type        = string
}

variable "password" {
  description = "Master password"
  type        = string
  sensitive   = true
}

variable "kms_key_id" {
  description = "KMS Key for encryption"
  type        = string
}

variable "rds_sg_id" {
  description = "Security group ID for RDS"
  type        = string
}

variable "db_subnet_group" {
  description = "Subnet group name"
  type        = string
}

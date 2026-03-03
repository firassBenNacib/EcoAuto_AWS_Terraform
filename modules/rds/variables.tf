variable "identifier" {
  description = "RDS instance identifier"
  type        = string
  default     = "ecoauto-rds"
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

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "RDS backup retention in days"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy"
  type        = bool
  default     = true
}

variable "final_snapshot_identifier" {
  description = "Optional final snapshot identifier when skip_final_snapshot is false"
  type        = string
  default     = null
}

variable "enable_iam_database_auth" {
  description = "Enable IAM database authentication"
  type        = bool
  default     = true
}

variable "enable_performance_insights" {
  description = "Enable RDS Performance Insights"
  type        = bool
  default     = false
}

variable "performance_insights_kms_key_id" {
  description = "Optional KMS key ARN for Performance Insights"
  type        = string
  default     = null
}

variable "kms_key_id" {
  description = "KMS Key ARN for encryption"
  type        = string
  default     = null
}

variable "rds_sg_id" {
  description = "Security group ID for RDS"
  type        = string
}

variable "db_subnet_ids" {
  description = "Private subnet IDs for RDS subnet group"
  type        = list(string)
}

variable "enable_workspace_suffix" {
  description = "Suffix RDS identifiers with workspace"
  type        = bool
  default     = false
}

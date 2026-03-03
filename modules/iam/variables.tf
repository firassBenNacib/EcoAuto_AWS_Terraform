variable "aws_region" {
  description = "AWS region where ASG and RDS resources exist"
  type        = string
}

variable "asg_name" {
  description = "ASG name used for least-privilege IAM scoping"
  type        = string
}

variable "rds_instance_id" {
  description = "RDS DB instance identifier used for least-privilege IAM scoping"
  type        = string
}

variable "enable_workspace_suffix" {
  description = "Suffix IAM role/policy names with workspace"
  type        = bool
  default     = false
}

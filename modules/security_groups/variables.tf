variable "vpc_id" {
  description = "The ID of the VPC where security groups are created"
  type        = string
}

variable "app_port" {
  description = "Backend application port"
  type        = number
  default     = 8080
}

variable "enable_ssh_admin" {
  description = "Whether SSH ingress from admin_cidr should be enabled"
  type        = bool
  default     = false
}

variable "admin_cidr" {
  description = "Admin CIDR allowed for optional SSH access"
  type        = string
  default     = "203.0.113.10/32"
}

variable "cloudfront_origin_prefix_list_name" {
  description = "AWS managed prefix list name for CloudFront origin-facing traffic"
  type        = string
  default     = "com.amazonaws.global.cloudfront.origin-facing"
}

variable "enable_workspace_suffix" {
  description = "Suffix security group names with workspace"
  type        = bool
  default     = false
}

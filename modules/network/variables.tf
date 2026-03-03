variable "vpc_name" {
  description = "Name tag for the VPC"
  type        = string
  default     = "ecoauto-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones used by the network"
  type        = list(string)
}

variable "public_app_subnet_cidrs" {
  description = "CIDR blocks for public app subnets"
  type        = list(string)
}

variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for private DB subnets"
  type        = list(string)
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs to CloudWatch Logs"
  type        = bool
  default     = false
}

variable "flow_logs_retention_days" {
  description = "Retention days for the VPC Flow Logs CloudWatch log group"
  type        = number
  default     = 30
}

variable "lockdown_default_security_group" {
  description = "When true, removes all rules from the default security group for this VPC"
  type        = bool
  default     = true
}

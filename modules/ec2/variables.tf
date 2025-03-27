variable "ami_id" {
  description = "AMI ID for EC2"
  type        = string
}

variable "instance_type" {
  description = "EC2 Instance Type"
  type        = string
  default     = "t4g.nano"
}

variable "key_name" {
  description = "EC2 Key Pair Name"
  type        = string
}

variable "subnet_ids" {
  description = "List of Subnet IDs"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "user_data_script" {
  description = "Script file for EC2 user data"
  type        = string
  default     = "your-user-data-script.sh"
}

variable "rds_endpoint" {
  description = "RDS Endpoint for app connectivity"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM Instance Profile Name"
  type        = string
}

variable "launch_template_prefix" {
  description = "Prefix for launch template"
  type        = string
  default     = "your-launch-template-prefix-"
}

variable "ec2_instance_name" {
  description = "Name tag for EC2 instances"
  type        = string
  default     = "your-ec2-instance-name"
}

variable "asg_name" {
  description = "Auto Scaling Group Name"
  type        = string
  default     = "your-asg-name"
}

variable "desired_capacity" {
  description = "Desired number of instances"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
  default     = 1
}

variable "cpu_target_value" {
  description = "Target CPU utilization for ASG"
  type        = number
  default     = 70.0
}

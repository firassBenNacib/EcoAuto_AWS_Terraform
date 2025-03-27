variable "lambda_sg_update_role_arn" {
  type = string
}

variable "infra_update_lambda_role_arn" {
  type = string
}

variable "scheduler_lambda_role_arn" {
  type = string
}

variable "lambda_edge_role_arn" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "asg_name" {
  type = string
}

variable "rds_instance_id" {
  type = string
}

variable "backend_cf_dist_id" {
  type = string
}

variable "route53_zone_id" {
  type = string
}

variable "frontend_cf_domain" {
  type = string
}

variable "backend_alias" {
  type = string
}

variable "frontend_alias" {
  type = string
}

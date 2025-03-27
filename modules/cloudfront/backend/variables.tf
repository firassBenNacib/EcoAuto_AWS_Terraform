variable "backend_domain_name" {
  description = "Backend origin domain name"
  type        = string
  default     = "your-backend-domain.com"
}

variable "backend_alias" {
  description = "Alias for backend CloudFront"
  type        = string
}

variable "backend_cert_arn" {
  description = "ACM certificate ARN for backend"
  type        = string
}

variable "lambda_edge_arn" {
  description = "Lambda@Edge ARN"
  type        = string
}

variable "cache_policy_id" {
  description = "CloudFront cache policy ID"
  type        = string
  default     = "your-cache-policy-id"
}

variable "origin_request_policy_id" {
  description = "CloudFront origin request policy ID"
  type        = string
  default     = "your-origin-request-policy-id"
}

variable "geo_locations" {
  description = "List of allowed geo locations"
  type        = list(string)
  default     = ["US", "GB", "CA"] # example
}

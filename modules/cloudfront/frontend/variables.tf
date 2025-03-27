variable "frontend_bucket_domain" {
  description = "S3 bucket domain name"
  type        = string
}

variable "frontend_aliases" {
  description = "Frontend aliases for CloudFront"
  type        = list(string)
}

variable "frontend_cert_arn" {
  description = "ACM certificate ARN for frontend"
  type        = string
}

variable "cache_policy_id" {
  description = "CloudFront cache policy ID"
  type        = string
  default     = "your-cache-policy-id"
}

variable "response_headers_policy_id" {
  description = "CloudFront response headers policy ID"
  type        = string
  default     = "your-response-headers-policy-id"
}

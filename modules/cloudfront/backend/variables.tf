variable "backend_domain_name" {
  description = "Initial backend origin domain name"
  type        = string
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
  description = "Lambda@Edge ARN for origin request routing"
  type        = string
}

variable "cache_policy_id" {
  description = "CloudFront cache policy ID"
  type        = string
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.price_class)
    error_message = "price_class must be one of PriceClass_All, PriceClass_200, or PriceClass_100."
  }
}

variable "origin_request_policy_id" {
  description = "CloudFront origin request policy ID"
  type        = string
}

variable "viewer_protocol_policy" {
  description = "Viewer protocol policy for the backend distribution default cache behavior"
  type        = string
  default     = "redirect-to-https"

  validation {
    condition     = contains(["allow-all", "redirect-to-https", "https-only"], var.viewer_protocol_policy)
    error_message = "viewer_protocol_policy must be one of allow-all, redirect-to-https, or https-only."
  }
}

variable "app_port" {
  description = "Backend application port"
  type        = number
  default     = 8080
}

variable "origin_protocol_policy" {
  description = "CloudFront-to-origin protocol policy"
  type        = string
  default     = "http-only"

  validation {
    condition     = contains(["http-only", "https-only"], var.origin_protocol_policy)
    error_message = "origin_protocol_policy must be either 'http-only' or 'https-only'."
  }
}

variable "geo_locations" {
  description = "List of allowed geo locations"
  type        = list(string)
  default     = ["US", "GB", "CA"]
}

variable "enable_origin_auth_header" {
  description = "Enable custom origin authentication headers"
  type        = bool
  default     = true
}

variable "origin_auth_header_name" {
  description = "Primary custom header name for origin auth"
  type        = string
  default     = "X-Origin-Verify"
}

variable "origin_auth_header_value" {
  description = "Primary custom header value for origin auth"
  type        = string
  default     = ""
  sensitive   = true
}

variable "origin_auth_previous_header_name" {
  description = "Secondary custom header name for origin auth rotation"
  type        = string
  default     = "X-Origin-Verify-Prev"
}

variable "origin_auth_previous_header_value" {
  description = "Secondary custom header value for origin auth rotation"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_access_logs" {
  description = "Enable CloudFront standard access logs"
  type        = bool
  default     = false
}

variable "access_logs_bucket" {
  description = "S3 bucket domain name for CloudFront logs (for example bucket.s3.amazonaws.com)"
  type        = string
  default     = ""

  validation {
    condition     = !var.enable_access_logs || trimspace(var.access_logs_bucket) != ""
    error_message = "access_logs_bucket must be set when enable_access_logs=true."
  }
}

variable "access_logs_prefix" {
  description = "Prefix used for backend CloudFront log objects"
  type        = string
  default     = "cloudfront/backend/"
}

variable "enable_workspace_suffix" {
  description = "Suffix backend aliases and tags with workspace"
  type        = bool
  default     = false
}

variable "ignore_dynamic_origin_drift" {
  description = "Ignore origin/target-origin drift managed outside Terraform by update-infra Lambda."
  type        = bool
  default     = true
}

variable "web_acl_id" {
  description = "Optional WAFv2 Web ACL ARN"
  type        = string
  default     = null
}

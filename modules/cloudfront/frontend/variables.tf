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
  default     = "658327ea-f89d-4fab-a63d-7e88639e58f6"
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

variable "response_headers_policy_id" {
  description = "CloudFront response headers policy ID"
  type        = string
  default     = "67f7725c-6f97-4210-82d7-5512b31e9d03"
}

variable "viewer_protocol_policy" {
  description = "Viewer protocol policy for the frontend distribution default cache behavior"
  type        = string
  default     = "https-only"

  validation {
    condition     = contains(["allow-all", "redirect-to-https", "https-only"], var.viewer_protocol_policy)
    error_message = "viewer_protocol_policy must be one of allow-all, redirect-to-https, or https-only."
  }
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
  description = "Prefix used for frontend CloudFront log objects"
  type        = string
  default     = "cloudfront/frontend/"
}

variable "enable_workspace_suffix" {
  description = "Suffix frontend aliases and tags with workspace"
  type        = bool
  default     = false
}

variable "workspace_domain" {
  description = "Base domain used to derive workspace aliases"
  type        = string
  default     = ""
}

variable "web_acl_id" {
  description = "Optional WAFv2 Web ACL ARN"
  type        = string
  default     = null
}

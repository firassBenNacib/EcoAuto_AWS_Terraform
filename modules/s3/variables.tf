variable "bucket_name" {
  description = "S3 bucket name for hosting frontend"
  type        = string
}

variable "force_destroy" {
  description = "Allow destroying non-empty S3 bucket"
  type        = bool
  default     = false
}

variable "versioning_enabled" {
  description = "Enable bucket versioning"
  type        = bool
  default     = true
}

variable "enable_kms_encryption" {
  description = "Use SSE-KMS for bucket encryption instead of SSE-S3"
  type        = bool
  default     = false
}

variable "kms_key_id" {
  description = "KMS key ID/ARN for SSE-KMS encryption"
  type        = string
  default     = null

  validation {
    condition     = !var.enable_kms_encryption || (var.kms_key_id != null && trimspace(var.kms_key_id) != "")
    error_message = "kms_key_id must be set when enable_kms_encryption=true."
  }
}

variable "enable_lifecycle" {
  description = "Enable lifecycle policy on the bucket"
  type        = bool
  default     = false
}

variable "lifecycle_expiration_days" {
  description = "Optional expiration age for current objects"
  type        = number
  default     = null
}

variable "lifecycle_noncurrent_expiration_days" {
  description = "Optional expiration age for noncurrent object versions"
  type        = number
  default     = 30
}

variable "lifecycle_abort_incomplete_multipart_upload_days" {
  description = "Abort incomplete multipart uploads after this many days"
  type        = number
  default     = 7

  validation {
    condition     = var.lifecycle_abort_incomplete_multipart_upload_days >= 1 && var.lifecycle_abort_incomplete_multipart_upload_days == floor(var.lifecycle_abort_incomplete_multipart_upload_days)
    error_message = "lifecycle_abort_incomplete_multipart_upload_days must be an integer >= 1."
  }
}

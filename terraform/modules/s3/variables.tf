variable "bucket_name" {
  description = "Globally unique S3 bucket name. Include the environment prefix so names do not collide between dev and prod (e.g. 'dev-app-artifacts')."
  type        = string
}

variable "environment" {
  description = "Deployment environment identifier (dev, staging, prod). Used in tags."
  type        = string
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key ARN for server-side encryption. Null falls back to AES256 with S3-managed keys, which is plenty for non-regulated data."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "When true, allows destroy of a non-empty bucket. False in prod; true is sometimes useful in short-lived dev for clean teardown."
  type        = bool
  default     = false
}

variable "noncurrent_version_transition_days" {
  description = "Days before noncurrent object versions transition to STANDARD_IA."
  type        = number
  default     = 30
}

variable "noncurrent_version_expiration_days" {
  description = "Days before noncurrent object versions are expired (deleted)."
  type        = number
  default     = 90
}

variable "incomplete_multipart_upload_days" {
  description = "Days before incomplete multipart uploads are aborted and cleaned up."
  type        = number
  default     = 7
}

variable "versioning_enabled" {
  description = "Whether to enable bucket versioning. Recommended ON for most workloads — protects against client-side accidental overwrites and ransomware-class operations."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags merged onto every resource created by this module."
  type        = map(string)
  default     = {}
}

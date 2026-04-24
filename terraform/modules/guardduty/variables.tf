variable "environment" {
  description = "Deployment environment identifier (dev, staging, prod). Used in tags."
  type        = string
}

variable "enable_s3_logs" {
  description = "Enable the S3_DATA_EVENTS feature. Adds per-object S3 read/write telemetry to the detector; modest cost, high signal when a bucket is ever exposed."
  type        = bool
  default     = true
}

variable "enable_lambda_logs" {
  description = "Enable the LAMBDA_NETWORK_LOGS feature. Catches Lambda functions making outbound calls to known-bad destinations — cheap insurance for the cost-aggregator Lambda."
  type        = bool
  default     = true
}

variable "enable_eks_audit_logs" {
  description = "Enable EKS_AUDIT_LOGS. This architecture does not use EKS, so the default is false; kept as a variable so the decision is explicit."
  type        = bool
  default     = false
}

variable "finding_publishing_frequency" {
  description = "How often the detector publishes findings to CloudWatch Events: FIFTEEN_MINUTES (default), ONE_HOUR, or SIX_HOURS."
  type        = string
  default     = "FIFTEEN_MINUTES"
  validation {
    condition     = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.finding_publishing_frequency)
    error_message = "finding_publishing_frequency must be FIFTEEN_MINUTES, ONE_HOUR, or SIX_HOURS."
  }
}

variable "tags" {
  description = "Additional tags merged onto every resource created by this module."
  type        = map(string)
  default     = {}
}

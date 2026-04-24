variable "environment" {
  description = "Deployment environment identifier (dev, staging, prod). Used in resource names and tags."
  type        = string
}

variable "name" {
  description = "Logical name for the ALB (e.g. 'public'). Prefixed with the environment to form the final name."
  type        = string
  default     = "public"
}

variable "vpc_id" {
  description = "VPC ID the ALB and its security group belong to."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs to attach the ALB to. Must span >= 2 AZs."
  type        = list(string)
  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "ALBs require public_subnet_ids to span at least 2 AZs."
  }
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the HTTPS listener. Real certificates are not checked into this repo; wire this at apply time."
  type        = string
}

variable "additional_certificate_arns" {
  description = "Extra ACM certificate ARNs to attach as SNI listener certificates (for additional host names)."
  type        = list(string)
  default     = []
}

variable "ssl_policy" {
  description = "SSL policy for the HTTPS listener. The TLS13 policies disable TLS 1.0/1.1 entirely."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "access_logs_bucket" {
  description = "S3 bucket name for ALB access logs. Null disables access logging. The bucket must already have the ALB service account policy attached."
  type        = string
  default     = null
}

variable "access_logs_prefix" {
  description = "Prefix within access_logs_bucket for this ALB's logs."
  type        = string
  default     = null
}

variable "idle_timeout" {
  description = "ALB idle timeout in seconds. Bump for long-lived requests (e.g. SSE, long polls); keep low otherwise."
  type        = number
  default     = 60
}

variable "enable_deletion_protection" {
  description = "When true, prevents the ALB from being destroyed. Set true for prod."
  type        = bool
  default     = false
}

variable "drop_invalid_header_fields" {
  description = "When true, the ALB drops requests with invalid HTTP headers rather than forwarding them."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags merged onto every resource created by this module."
  type        = map(string)
  default     = {}
}

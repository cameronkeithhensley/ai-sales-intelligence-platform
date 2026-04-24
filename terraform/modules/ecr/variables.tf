variable "environment" {
  description = "Deployment environment identifier (dev, staging, prod). Prefixed onto repository names."
  type        = string
}

variable "repositories" {
  description = "List of ECR repository names (typically one per agent / service)."
  type        = list(string)
}

variable "keep_last_tagged_count" {
  description = "Number of tagged images to retain before the lifecycle policy expires the oldest."
  type        = number
  default     = 20
}

variable "expire_untagged_after_days" {
  description = "How long untagged images survive before the lifecycle policy expires them."
  type        = number
  default     = 7
}

variable "image_tag_mutability" {
  description = "ECR tag mutability. IMMUTABLE is strongly recommended — prevents 'pushed :latest on top of what was already :latest' footguns."
  type        = string
  default     = "IMMUTABLE"
  validation {
    condition     = contains(["IMMUTABLE", "MUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be IMMUTABLE or MUTABLE."
  }
}

variable "tags" {
  description = "Additional tags merged onto every repository created by this module."
  type        = map(string)
  default     = {}
}

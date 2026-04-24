variable "environment" {
  description = "Deployment environment identifier (dev, staging, prod). Used in resource tags."
  type        = string
}

variable "user_pool_name" {
  description = "Name of the user pool."
  type        = string
}

variable "domain_prefix" {
  description = "Cognito hosted-UI domain prefix. Must be globally unique within the region (e.g. 'ai-sip-dev')."
  type        = string
}

variable "callback_urls" {
  description = "Allowed OAuth redirect URLs after a successful sign-in."
  type        = list(string)
  validation {
    condition     = length(var.callback_urls) > 0
    error_message = "At least one callback URL is required."
  }
}

variable "logout_urls" {
  description = "Allowed redirect URLs after sign-out."
  type        = list(string)
  default     = []
}

variable "mfa_configuration" {
  description = "Cognito MFA configuration: 'OFF', 'ON' (required), or 'OPTIONAL'. OPTIONAL is a reasonable dev default."
  type        = string
  default     = "OPTIONAL"
  validation {
    condition     = contains(["OFF", "ON", "OPTIONAL"], var.mfa_configuration)
    error_message = "mfa_configuration must be one of OFF, ON, OPTIONAL."
  }
}

variable "access_token_validity_minutes" {
  description = "Access token validity window in minutes."
  type        = number
  default     = 60
}

variable "id_token_validity_minutes" {
  description = "ID token validity window in minutes."
  type        = number
  default     = 60
}

variable "refresh_token_validity_days" {
  description = "Refresh token validity window in days."
  type        = number
  default     = 30
}

variable "client_name" {
  description = "Name of the user pool client (web app)."
  type        = string
  default     = "web-client"
}

variable "deletion_protection" {
  description = "When ACTIVE, the pool cannot be deleted. Set ACTIVE for prod."
  type        = string
  default     = "INACTIVE"
  validation {
    condition     = contains(["ACTIVE", "INACTIVE"], var.deletion_protection)
    error_message = "deletion_protection must be ACTIVE or INACTIVE."
  }
}

variable "tags" {
  description = "Additional tags merged onto every resource created by this module."
  type        = map(string)
  default     = {}
}

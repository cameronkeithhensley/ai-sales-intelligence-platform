variable "environment" {
  description = "Deployment environment identifier (dev, staging, prod). Used in configuration set names and tags."
  type        = string
}

variable "domain_name" {
  description = "Base domain to register as an SES identity (e.g. 'example.com'). DKIM and MAIL FROM records are generated for this domain; the Route53 / DNS records themselves are managed outside this module."
  type        = string
}

variable "mail_from_subdomain" {
  description = "Subdomain (appended to domain_name) used as the SMTP MAIL FROM. Must be different from the From: domain."
  type        = string
  default     = "bounce"
}

variable "configuration_set_name" {
  description = "Name of the configuration set. Defaults to '<environment>-transactional'."
  type        = string
  default     = null
}

variable "tls_policy" {
  description = "Minimum TLS policy applied to outbound mail: REQUIRE or OPTIONAL. REQUIRE means SES will not send to a recipient MX that does not offer STARTTLS."
  type        = string
  default     = "REQUIRE"
  validation {
    condition     = contains(["REQUIRE", "OPTIONAL"], var.tls_policy)
    error_message = "tls_policy must be REQUIRE or OPTIONAL."
  }
}

variable "tags" {
  description = "Additional tags merged onto every resource created by this module."
  type        = map(string)
  default     = {}
}

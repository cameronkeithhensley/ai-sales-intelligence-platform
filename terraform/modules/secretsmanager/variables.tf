variable "environment" {
  description = "Deployment environment identifier (dev, staging, prod). Injected into the secret path."
  type        = string
}

variable "secrets" {
  description = "Map of secret logical name -> human-readable description. Values are written out-of-band; this module only declares the containers."
  type        = map(string)
}

variable "path_prefix" {
  description = "Leading component of every secret's full path. Combined with environment and key: {path_prefix}/{environment}/{key}."
  type        = string
  default     = "/example-app"
}

variable "recovery_window_in_days" {
  description = "Days between aws_secretsmanager_secret.delete and actual deletion. 7 is the minimum that still provides meaningful undo-on-oopsie; 0 forces immediate (destructive) deletion."
  type        = number
  default     = 7
}

variable "kms_key_id" {
  description = "KMS key ID/ARN for secret encryption. Null => AWS-managed default Secrets Manager key."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags merged onto every secret created by this module."
  type        = map(string)
  default     = {}
}

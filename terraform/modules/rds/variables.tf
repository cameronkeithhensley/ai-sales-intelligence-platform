variable "environment" {
  description = "Deployment environment identifier (dev, staging, prod). Used in resource names and tags."
  type        = string
}

variable "identifier" {
  description = "Base identifier used for the DB instance and its collaborator resources (subnet group, parameter group, security group)."
  type        = string
  default     = "app-db"
}

variable "engine_version" {
  description = "PostgreSQL engine version. Keep aligned with the parameter group family."
  type        = string
  default     = "15.4"
}

variable "parameter_group_family" {
  description = "RDS parameter group family matching the engine version (e.g. postgres15)."
  type        = string
  default     = "postgres15"
}

variable "instance_class" {
  description = "DB instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GiB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Upper bound for storage autoscaling. Set equal to allocated_storage to disable autoscaling."
  type        = number
  default     = 100
}

variable "multi_az" {
  description = "Run the instance in multi-AZ mode (synchronous standby). Disable in dev for cost; enable in prod."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups (0 disables)."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "When true, prevents the instance from being destroyed. Set true for prod."
  type        = bool
  default     = false
}

variable "db_subnet_ids" {
  description = "List of private subnet IDs for the DB subnet group. Spans >= 2 AZs."
  type        = list(string)
  validation {
    condition     = length(var.db_subnet_ids) >= 2
    error_message = "RDS requires db_subnet_ids to span at least 2 AZs."
  }
}

variable "allowed_security_group_ids" {
  description = "Security group IDs permitted to reach the DB on the engine port (bastion SG + ECS task SG, typically)."
  type        = list(string)
  default     = []
}

variable "vpc_id" {
  description = "VPC ID the DB security group belongs to."
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID/ARN for storage encryption. Null => AWS-managed default RDS key."
  type        = string
  default     = null
}

variable "master_username" {
  description = "Master DB username."
  type        = string
  default     = "app_admin"
}

variable "master_password_secret_arn" {
  description = "ARN of an existing Secrets Manager secret holding the master password (JSON with a 'password' key, or a plain string). If null, the module generates and manages the password itself. Using a secret is the recommended path."
  type        = string
  default     = null
}

variable "db_name" {
  description = "Initial database name to create on the instance. Null skips creation."
  type        = string
  default     = null
}

variable "port" {
  description = "Port the instance listens on."
  type        = number
  default     = 5432
}

variable "performance_insights_retention_period" {
  description = "Performance Insights retention in days (7 for free tier, 731 for long-term)."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Additional tags merged onto every resource created by this module."
  type        = map(string)
  default     = {}
}

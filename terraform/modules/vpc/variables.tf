variable "environment" {
  description = "Deployment environment identifier (e.g. dev, staging, prod). Used in resource Name tags."
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to span. Must be >= 1 and <= length(public_subnet_cidrs)/length(private_subnet_cidrs)."
  type        = number
  default     = 2
  validation {
    condition     = var.az_count >= 1 && var.az_count <= 6
    error_message = "az_count must be between 1 and 6."
  }
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets. One per AZ; length must be >= az_count."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets. One per AZ; length must be >= az_count."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "multi_nat_enabled" {
  description = "When true, provision one NAT gateway per AZ (AZ-resilient, higher cost). When false, one shared NAT gateway in the first public subnet."
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "When true, emit VPC flow logs to a dedicated CloudWatch log group."
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Retention period for the VPC flow logs CloudWatch log group."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Additional tags merged onto every resource created by this module."
  type        = map(string)
  default     = {}
}

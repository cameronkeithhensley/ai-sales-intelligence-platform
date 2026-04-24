variable "aws_account_id" {
  description = "AWS account ID this environment targets. Pinned via allowed_account_ids so the provider refuses to operate against any other account."
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment identifier. Drives resource names and tags across every module."
  type        = string
  default     = "dev"
}

variable "domain_name" {
  description = "Base public hostname for this environment (e.g. dev.example.com). Real domains are never committed."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the environment VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones the VPC should span."
  type        = number
  default     = 2
}

variable "public_subnet_cidrs" {
  description = "CIDRs for the public subnets, one per AZ."
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for the private subnets, one per AZ."
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]
}

variable "multi_nat_enabled" {
  description = "Whether to provision one NAT gateway per AZ (true) or a single shared NAT (false). False is correct for dev."
  type        = bool
  default     = false
}

variable "rds_instance_class" {
  description = "RDS instance class for the dev database."
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Initial allocated storage (GiB) for the dev database."
  type        = number
  default     = 20
}

variable "rds_multi_az" {
  description = "Whether the dev RDS instance runs multi-AZ. False to keep dev costs down."
  type        = bool
  default     = false
}

variable "rds_deletion_protection" {
  description = "Whether deletion protection is on for the dev RDS instance. False in dev so the environment can be torn down cleanly."
  type        = bool
  default     = false
}

variable "bastion_instance_type" {
  description = "EC2 instance type for the bastion host."
  type        = string
  default     = "t3.micro"
}

variable "alb_certificate_arn" {
  description = "ACM certificate ARN for the public ALB HTTPS listener. Real certs are not checked in; this is supplied at apply time."
  type        = string
  default     = "arn:aws:acm:us-east-1:000000000000:certificate/00000000-0000-0000-0000-000000000000"
}

variable "cognito_domain_prefix" {
  description = "Globally-unique Cognito hosted-UI domain prefix for this environment."
  type        = string
  default     = "ai-sip-dev"
}

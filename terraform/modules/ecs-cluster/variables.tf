variable "name" {
  description = "Cluster name. Prefix with the environment (e.g. 'dev-agents') so the name is unique per account/region."
  type        = string
}

variable "environment" {
  description = "Deployment environment identifier (dev, staging, prod). Used in tags."
  type        = string
}

variable "capacity_provider_default_weights" {
  description = "Map of capacity provider name -> default strategy weight. Must include 'FARGATE' and 'FARGATE_SPOT'. Weight of 0 disables that provider as a default target (the capacity provider is still associated, so task definitions may opt in explicitly)."
  type        = map(number)
  default = {
    FARGATE      = 1
    FARGATE_SPOT = 0
  }
  validation {
    condition     = length(setsubtract(keys(var.capacity_provider_default_weights), ["FARGATE", "FARGATE_SPOT"])) == 0
    error_message = "capacity_provider_default_weights may only contain FARGATE and FARGATE_SPOT keys."
  }
}

variable "container_insights_enabled" {
  description = "Whether to enable CloudWatch Container Insights on the cluster. Adds ~a few dollars per month but provides per-task CPU/memory/network metrics that you cannot recover after the fact."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags merged onto every resource created by this module."
  type        = map(string)
  default     = {}
}

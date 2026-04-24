variable "name" {
  description = "Logical name of the web ACL. The full name is '<environment>-<name>-waf' so multiple ACLs per environment can coexist."
  type        = string
}

variable "environment" {
  description = "Deployment environment identifier (dev, staging, prod). Used in names and tags."
  type        = string
}

variable "alb_arn" {
  description = "ARN of the ALB to associate the web ACL with. REGIONAL scope; CloudFront would require a separate us-east-1 WAF."
  type        = string
}

variable "rate_limit_per_5min" {
  description = "Rate-based rule: requests allowed per 5-minute window per IP before the rule blocks. 2000 is a reasonable default for a small multi-tenant app (roughly 6.7 req/sec sustained)."
  type        = number
  default     = 2000
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for WAF request logs."
  type        = number
  default     = 30
}

variable "managed_rule_groups" {
  description = "List of AWS managed rule groups to enable. Each entry maps to an AWSManagedRulesXxxRuleSet rule."
  type = list(object({
    name           = string
    priority       = number
    metric_name    = string
    excluded_rules = optional(list(string), [])
  }))
  default = [
    { name = "AWSManagedRulesCommonRuleSet", priority = 10, metric_name = "CommonRules" },
    { name = "AWSManagedRulesKnownBadInputsRuleSet", priority = 20, metric_name = "KnownBadInputs" },
    { name = "AWSManagedRulesAmazonIpReputationList", priority = 30, metric_name = "IpReputation" },
    { name = "AWSManagedRulesSQLiRuleSet", priority = 40, metric_name = "SQLi" },
  ]
}

variable "tags" {
  description = "Additional tags merged onto every resource created by this module."
  type        = map(string)
  default     = {}
}

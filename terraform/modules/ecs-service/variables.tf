variable "service_name" {
  description = "Logical service name (e.g. 'dashboard', 'scout'). Used in resource names, log group paths, container names, and tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment identifier (dev, staging, prod). Used in resource names and tags."
  type        = string
}

variable "cluster_id" {
  description = "ID or ARN of the ECS cluster this service runs on."
  type        = string
}

variable "image_url" {
  description = "Fully qualified container image URL, including the tag (e.g. '<account>.dkr.ecr.<region>.amazonaws.com/dev/scout:abc123'). Do not pass ':latest' — pin a tag."
  type        = string
}

variable "container_port" {
  description = "Port the container listens on. Ignored in practice for pure worker services (load_balancer_enabled = false) but still stamped into the port mapping so logs / exec into the task know the listen port."
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "Task CPU in Fargate units (256, 512, 1024, ...). Must pair with a valid memory size per the Fargate sizing table."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Task memory in MiB. Must pair with cpu per the Fargate sizing table."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of tasks to keep running. Set to 0 to suspend the service without destroying it."
  type        = number
  default     = 1
}

variable "vpc_id" {
  description = "VPC ID the service security group belongs to."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ENI placement. Tasks get no public IP."
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_ids) >= 1
    error_message = "At least one private subnet is required."
  }
}

variable "env_vars" {
  description = "Non-secret environment variables injected into the container as plain strings. Use secret_arns for anything sensitive."
  type        = map(string)
  default     = {}
}

variable "secret_arns" {
  description = "Map of environment variable name -> Secrets Manager ARN (or the ARN of a specific JSON key, with a ':key::' suffix). ECS resolves these at task startup and injects the value as an environment variable. The task execution role is granted GetSecretValue on exactly these ARNs and no others."
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for the service's log group."
  type        = number
  default     = 30
}

variable "assign_public_ip" {
  description = "Whether the task ENIs get a public IP. Must be false for tasks in private subnets."
  type        = bool
  default     = false
}

variable "load_balancer_enabled" {
  description = "When true, create an ALB target group + listener rule and wire the service's load_balancer block. When false, the service is a pure worker (SQS consumer, cron, etc.) with no ALB integration."
  type        = bool
  default     = false
}

variable "alb_https_listener_arn" {
  description = "ALB HTTPS listener ARN. Required when load_balancer_enabled is true."
  type        = string
  default     = null
}

variable "alb_security_group_id" {
  description = "ALB security group ID. When load_balancer_enabled is true, the service SG accepts ingress on container_port only from this SG."
  type        = string
  default     = null
}

variable "host_header" {
  description = "Host header to match on the listener rule (e.g. 'dashboard.example.com'). Either host_header or path_patterns must be set when load-balanced."
  type        = string
  default     = null
}

variable "path_patterns" {
  description = "Path patterns to match on the listener rule (e.g. ['/api/*']). Combined with host_header via an AND if both are set."
  type        = list(string)
  default     = []
}

variable "listener_rule_priority" {
  description = "Priority for the listener rule. Must be unique across all rules on the listener."
  type        = number
  default     = null
}

variable "health_check_path" {
  description = "Path the ALB target group hits for health checks. Typically /healthz or /health."
  type        = string
  default     = "/healthz"
}

variable "health_check_grace_period_seconds" {
  description = "Seconds the ECS service waits before subjecting a new task to ALB health checks. Cover slow cold starts here; raise when a service has a heavy startup path."
  type        = number
  default     = 60
}

variable "deregistration_delay_seconds" {
  description = "Seconds the target group keeps a deregistering target draining. Lower for stateless services, higher (up to 300) for services with long-lived request handling."
  type        = number
  default     = 30
}

variable "additional_task_role_policy_arns" {
  description = "Extra IAM policy ARNs to attach to the task role. Typical inputs: SQS send/receive, S3 read, DynamoDB, specific bucket policies. The module does not create those policies — it only attaches them so the policy lifecycle stays with its owning module."
  type        = list(string)
  default     = []
}

variable "enable_execute_command" {
  description = "When true, enables ECS Exec on the service so operators can 'aws ecs execute-command' into a running task. Adds SSM session logs to CloudTrail."
  type        = bool
  default     = false
}

variable "capacity_provider_strategy" {
  description = "Optional capacity provider strategy override. Leave empty to inherit the cluster default; set to [{capacity_provider = 'FARGATE_SPOT', weight = 1, base = 0}] to pin onto Spot."
  type = list(object({
    capacity_provider = string
    weight            = number
    base              = optional(number, 0)
  }))
  default = []
}

variable "tags" {
  description = "Additional tags merged onto every resource created by this module."
  type        = map(string)
  default     = {}
}

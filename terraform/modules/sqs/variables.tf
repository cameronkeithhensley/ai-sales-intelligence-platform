variable "environment" {
  description = "Deployment environment identifier (dev, staging, prod). Prefixed onto queue names."
  type        = string
}

variable "queues" {
  description = "Map of queue name -> config. Each queue gets a matching -dlq DLQ; messages that fail max_receive_count times land on it."
  type = map(object({
    visibility_timeout_seconds = number
    message_retention_seconds  = number
    max_receive_count          = number
  }))
}

variable "dlq_message_retention_seconds" {
  description = "Message retention for DLQs (applied to every DLQ). Default 14 days — the SQS maximum — so failed messages are available long enough to inspect."
  type        = number
  default     = 1209600
}

variable "kms_master_key_id" {
  description = "KMS key ID for server-side encryption. 'alias/aws/sqs' uses the AWS-managed SQS key; null disables SSE-KMS (falls back to SSE-SQS, which SQS enables by default)."
  type        = string
  default     = "alias/aws/sqs"
}

variable "tags" {
  description = "Additional tags merged onto every resource created by this module."
  type        = map(string)
  default     = {}
}

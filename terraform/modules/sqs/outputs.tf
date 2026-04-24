output "queue_arns" {
  description = "Map of queue name (the var.queues key) -> main queue ARN."
  value       = { for k, q in aws_sqs_queue.main : k => q.arn }
}

output "queue_urls" {
  description = "Map of queue name -> main queue URL (the value SDKs use for SendMessage / ReceiveMessage)."
  value       = { for k, q in aws_sqs_queue.main : k => q.url }
}

output "queue_ids" {
  description = "Map of queue name -> main queue id (same as URL in the AWS provider)."
  value       = { for k, q in aws_sqs_queue.main : k => q.id }
}

output "dlq_arns" {
  description = "Map of queue name -> DLQ ARN."
  value       = { for k, q in aws_sqs_queue.dlq : k => q.arn }
}

output "dlq_urls" {
  description = "Map of queue name -> DLQ URL."
  value       = { for k, q in aws_sqs_queue.dlq : k => q.url }
}

output "service_name" {
  description = "Name of the ECS service."
  value       = aws_ecs_service.this.name
}

output "service_id" {
  description = "ID of the ECS service (composed <cluster>/<service>)."
  value       = aws_ecs_service.this.id
}

output "task_definition_arn" {
  description = "ARN of the task definition the service is pinned to. Revisions increase on every container-definition change."
  value       = aws_ecs_task_definition.this.arn
}

output "task_definition_family" {
  description = "Task definition family name. Useful for downstream deploy pipelines that register new revisions with 'aws ecs register-task-definition --family'."
  value       = aws_ecs_task_definition.this.family
}

output "security_group_id" {
  description = "Security group ID attached to service task ENIs. Add this SG as a source on RDS, ElastiCache, etc., when the service needs outbound access to them."
  value       = aws_security_group.this.id
}

output "task_role_arn" {
  description = "ARN of the task role. Attach additional IAM policies via var.additional_task_role_policy_arns rather than editing the role directly."
  value       = aws_iam_role.task.arn
}

output "task_role_name" {
  description = "Name of the task role."
  value       = aws_iam_role.task.name
}

output "execution_role_arn" {
  description = "ARN of the task execution role (used by the ECS agent to pull images and read secrets). Distinct from task_role — do not pile runtime app permissions here."
  value       = aws_iam_role.execution.arn
}

output "log_group_name" {
  description = "CloudWatch log group name for the service."
  value       = aws_cloudwatch_log_group.this.name
}

output "target_group_arn" {
  description = "Target group ARN when load_balancer_enabled; null otherwise."
  value       = var.load_balancer_enabled ? aws_lb_target_group.this[0].arn : null
}

output "listener_rule_arn" {
  description = "Listener rule ARN when load_balancer_enabled; null otherwise."
  value       = var.load_balancer_enabled ? aws_lb_listener_rule.this[0].arn : null
}

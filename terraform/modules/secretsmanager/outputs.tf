output "secret_arns" {
  description = "Map of logical secret name (var.secrets key) -> secret ARN. ECS task definitions should reference these ARNs via the 'secrets' block rather than being handed plaintext values."
  value       = { for k, s in aws_secretsmanager_secret.this : k => s.arn }
}

output "secret_ids" {
  description = "Map of logical secret name -> secret id. In AWS provider v5 the id is the ARN; kept as a separate output for forward-compat."
  value       = { for k, s in aws_secretsmanager_secret.this : k => s.id }
}

output "secret_names" {
  description = "Map of logical secret name -> fully-qualified secret path ({path_prefix}/{environment}/{name})."
  value       = { for k, s in aws_secretsmanager_secret.this : k => s.name }
}

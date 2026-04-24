output "repository_urls" {
  description = "Map of repository logical name (var.repositories entry) -> full repository URL (<account>.dkr.ecr.<region>.amazonaws.com/<env>/<name>)."
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "repository_arns" {
  description = "Map of repository logical name -> repository ARN. Use these when granting IAM access to specific repos."
  value       = { for k, r in aws_ecr_repository.this : k => r.arn }
}

output "repository_names" {
  description = "Map of repository logical name -> fully-qualified repository name (env/name)."
  value       = { for k, r in aws_ecr_repository.this : k => r.name }
}

output "registry_id" {
  description = "AWS account ID that owns the repositories (the ECR registry id). Same for every repo in a given account."
  value       = length(local.repos) > 0 ? values(aws_ecr_repository.this)[0].registry_id : null
}

output "vpc_id" {
  description = "ID of the dev VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs in the dev VPC."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs in the dev VPC."
  value       = module.vpc.private_subnet_ids
}

output "rds_endpoint" {
  description = "Connection endpoint of the dev RDS instance. Reachable only from approved security groups."
  value       = module.rds.endpoint
}

output "rds_security_group_id" {
  description = "Security group ID guarding the dev RDS instance. Add task SGs to the allowlist via the RDS module, not by editing this SG."
  value       = module.rds.security_group_id
}

output "alb_dns_name" {
  description = "DNS name of the public ALB. Front with a Route 53 ALIAS record pointing to domain_name."
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the public ALB."
  value       = module.alb.alb_zone_id
}

output "alb_https_listener_arn" {
  description = "ARN of the ALB HTTPS listener. Sprint 2 listener rules attach here."
  value       = module.alb.https_listener_arn
}

output "cognito_user_pool_id" {
  description = "ID of the dev Cognito user pool."
  value       = module.cognito.user_pool_id
}

output "cognito_user_pool_client_id" {
  description = "ID of the confidential dashboard client on the dev user pool."
  value       = module.cognito.user_pool_client_id
}

output "cognito_user_pool_domain" {
  description = "Cognito hosted-UI domain prefix for dev."
  value       = module.cognito.user_pool_domain
}

output "ecr_repository_urls" {
  description = "Map of logical service name -> ECR repository URL."
  value       = module.ecr.repository_urls
}

output "sqs_queue_urls" {
  description = "Map of logical queue name -> SQS queue URL."
  value       = module.sqs.queue_urls
}

output "sqs_dlq_urls" {
  description = "Map of logical queue name -> SQS DLQ URL."
  value       = module.sqs.dlq_urls
}

output "secret_arns" {
  description = "Map of logical secret name -> Secrets Manager ARN. ECS task definitions reference these directly."
  value       = module.secrets.secret_arns
}

output "bastion_instance_id" {
  description = "EC2 instance ID of the bastion. Use with: aws ssm start-session --target <id>."
  value       = module.bastion.instance_id
}

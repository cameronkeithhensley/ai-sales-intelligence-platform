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

# --- Agent services layer (Sprint 2) --------------------------------------

output "ecs_cluster_arn" {
  description = "ARN of the dev ECS cluster that hosts every agent service."
  value       = module.ecs_cluster.cluster_arn
}

output "ecs_cluster_name" {
  description = "Name of the dev ECS cluster."
  value       = module.ecs_cluster.cluster_name
}

output "service_target_group_arns" {
  description = "Map of load-balanced service name -> ALB target group ARN. Useful for wiring CloudWatch alarms to request counts / 5xx rates."
  value = {
    dashboard  = module.ecs_service_dashboard.target_group_arn
    holdsworth = module.ecs_service_holdsworth.target_group_arn
    admin-mcp  = module.ecs_service_admin_mcp.target_group_arn
  }
}

output "service_task_role_arns" {
  description = "Map of service name -> task role ARN. Additional policies can be attached to these via aws_iam_role_policy_attachment elsewhere."
  value = {
    dashboard  = module.ecs_service_dashboard.task_role_arn
    holdsworth = module.ecs_service_holdsworth.task_role_arn
    admin-mcp  = module.ecs_service_admin_mcp.task_role_arn
    scout      = module.ecs_service_scout.task_role_arn
    harvester  = module.ecs_service_harvester.task_role_arn
    profiler   = module.ecs_service_profiler.task_role_arn
    writer     = module.ecs_service_writer.task_role_arn
  }
}

output "service_security_group_ids" {
  description = "Map of service name -> ENI security group id. Add these as sources on RDS / ElastiCache SGs to admit the service."
  value = {
    dashboard  = module.ecs_service_dashboard.security_group_id
    holdsworth = module.ecs_service_holdsworth.security_group_id
    admin-mcp  = module.ecs_service_admin_mcp.security_group_id
    scout      = module.ecs_service_scout.security_group_id
    harvester  = module.ecs_service_harvester.security_group_id
    profiler   = module.ecs_service_profiler.security_group_id
    writer     = module.ecs_service_writer.security_group_id
  }
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF web ACL attached to the public ALB."
  value       = module.waf.web_acl_arn
}

output "guardduty_detector_id" {
  description = "GuardDuty detector id for the dev account/region."
  value       = module.guardduty.detector_id
}

output "ses_configuration_set_name" {
  description = "SES configuration set name. Applications must pass this on every send to get reputation metrics + event publishing."
  value       = module.ses.configuration_set_name
}

output "ses_dkim_tokens" {
  description = "SES DKIM tokens. Publish as CNAME records in the domain's DNS; this repo does not manage DNS."
  value       = module.ses.dkim_tokens
}

output "s3_artifacts_bucket_arn" {
  description = "ARN of the per-environment S3 artifacts bucket."
  value       = module.s3_artifacts.bucket_arn
}

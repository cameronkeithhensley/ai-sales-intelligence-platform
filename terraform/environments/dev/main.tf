locals {
  common_tags = {
    # Environment / Project / ManagedBy are applied via provider default_tags.
    # This map is for environment-specific overlays only.
  }

  # Logical agent queue set. Kept in one place so the SQS and IAM wiring
  # stay in lockstep as new agents are added.
  agent_queue_config = {
    scout-jobs = {
      visibility_timeout_seconds = 60
      message_retention_seconds  = 345600 # 4 days
      max_receive_count          = 5
    }
    harvester-jobs = {
      visibility_timeout_seconds = 300
      message_retention_seconds  = 345600
      max_receive_count          = 3
    }
    profiler-jobs = {
      visibility_timeout_seconds = 300
      message_retention_seconds  = 345600
      max_receive_count          = 3
    }
    writer-jobs = {
      visibility_timeout_seconds = 600
      message_retention_seconds  = 345600
      max_receive_count          = 2
    }
  }

  ecr_repositories = [
    "scout",
    "harvester",
    "profiler",
    "writer",
    "holdsworth",
    "admin-mcp",
  ]

  secrets = {
    db-master-password            = "Master password for the application RDS instance."
    jwt-signing-key               = "HMAC signing key for application-issued JWTs."
    anthropic-api-key             = "Anthropic API key for the writer agent."
    sms-provider-token            = "API token for the SMS provider."
    email-delivery-provider-token = "API token for the email delivery provider."
    person-data-api-key           = "API key for the person-data API."
  }
}

module "vpc" {
  source = "../../modules/vpc"

  environment          = var.environment
  cidr_block           = var.vpc_cidr
  az_count             = var.az_count
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  multi_nat_enabled    = var.multi_nat_enabled
  enable_flow_logs     = true

  tags = local.common_tags
}

module "ecr" {
  source = "../../modules/ecr"

  environment  = var.environment
  repositories = local.ecr_repositories

  tags = local.common_tags
}

module "sqs" {
  source = "../../modules/sqs"

  environment = var.environment
  queues      = local.agent_queue_config

  tags = local.common_tags
}

module "secrets" {
  source = "../../modules/secretsmanager"

  environment = var.environment
  path_prefix = "/example-app"
  secrets     = local.secrets

  tags = local.common_tags
}

module "bastion" {
  source = "../../modules/bastion"

  environment   = var.environment
  name          = "bastion"
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.private_subnet_ids[0]
  instance_type = var.bastion_instance_type

  tags = local.common_tags
}

module "rds" {
  source = "../../modules/rds"

  environment             = var.environment
  identifier              = "app-db"
  db_name                 = "app_db"
  engine_version          = "15.4"
  parameter_group_family  = "postgres15"
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  multi_az                = var.rds_multi_az
  backup_retention_period = 7
  deletion_protection     = var.rds_deletion_protection

  vpc_id                     = module.vpc.vpc_id
  db_subnet_ids              = module.vpc.private_subnet_ids
  allowed_security_group_ids = [module.bastion.security_group_id]

  master_password_secret_arn = module.secrets.secret_arns["db-master-password"]

  tags = local.common_tags
}

module "alb" {
  source = "../../modules/alb"

  environment       = var.environment
  name              = "public"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  certificate_arn   = var.alb_certificate_arn

  tags = local.common_tags
}

module "cognito" {
  source = "../../modules/cognito"

  environment    = var.environment
  user_pool_name = "${var.environment}-users"
  domain_prefix  = var.cognito_domain_prefix

  callback_urls = [
    "https://${var.domain_name}/api/auth/callback/cognito",
  ]
  logout_urls = [
    "https://${var.domain_name}/",
  ]

  tags = local.common_tags
}

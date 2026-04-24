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
    "dashboard",
  ]

  # Image tag applied to every task definition this sprint. Sprint 3 will
  # replace this with a pipeline-supplied git-sha tag.
  image_tag = "placeholder-sprint-2"

  # Per-service task sizing. Dev uses the Fargate-minimum shape across the
  # board; Sprint 2 is concerned with shape, not scale.
  task_sizing = {
    dashboard  = { cpu = 256, memory = 512 }
    holdsworth = { cpu = 256, memory = 512 }
    admin-mcp  = { cpu = 256, memory = 512 }
    writer     = { cpu = 256, memory = 512 }
    scout      = { cpu = 256, memory = 512 }
    harvester  = { cpu = 256, memory = 512 }
    profiler   = { cpu = 512, memory = 1024 }
  }

  # ECR image URLs pinned to image_tag, keyed by service name.
  service_image_urls = {
    for svc in local.ecr_repositories : svc => "${module.ecr.repository_urls[svc]}:${local.image_tag}"
  }

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

# --- Agent services layer (Sprint 2) --------------------------------------

module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  name        = "${var.environment}-agents"
  environment = var.environment

  tags = local.common_tags
}

# ---- Load-balanced services ----

module "ecs_service_dashboard" {
  source = "../../modules/ecs-service"

  service_name   = "dashboard"
  environment    = var.environment
  cluster_id     = module.ecs_cluster.cluster_id
  image_url      = local.service_image_urls["dashboard"]
  container_port = 8080
  cpu            = local.task_sizing["dashboard"].cpu
  memory         = local.task_sizing["dashboard"].memory
  desired_count  = 1

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  secret_arns = {
    DATABASE_URL    = module.secrets.secret_arns["db-master-password"]
    JWT_SIGNING_KEY = module.secrets.secret_arns["jwt-signing-key"]
  }

  env_vars = {
    NODE_ENV                    = "production"
    COGNITO_USER_POOL_ID        = module.cognito.user_pool_id
    COGNITO_USER_POOL_CLIENT_ID = module.cognito.user_pool_client_id
  }

  load_balancer_enabled  = true
  alb_https_listener_arn = module.alb.https_listener_arn
  alb_security_group_id  = module.alb.security_group_id
  host_header            = "dashboard.${var.domain_name}"
  listener_rule_priority = 100
  health_check_path      = "/healthz"

  tags = local.common_tags
}

module "ecs_service_holdsworth" {
  source = "../../modules/ecs-service"

  service_name   = "holdsworth"
  environment    = var.environment
  cluster_id     = module.ecs_cluster.cluster_id
  image_url      = local.service_image_urls["holdsworth"]
  container_port = 8080
  cpu            = local.task_sizing["holdsworth"].cpu
  memory         = local.task_sizing["holdsworth"].memory
  desired_count  = 1

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  secret_arns = {
    DATABASE_URL                  = module.secrets.secret_arns["db-master-password"]
    JWT_SIGNING_KEY               = module.secrets.secret_arns["jwt-signing-key"]
    SMS_PROVIDER_TOKEN            = module.secrets.secret_arns["sms-provider-token"]
    EMAIL_DELIVERY_PROVIDER_TOKEN = module.secrets.secret_arns["email-delivery-provider-token"]
  }

  env_vars = {
    NODE_ENV = "production"
  }

  load_balancer_enabled  = true
  alb_https_listener_arn = module.alb.https_listener_arn
  alb_security_group_id  = module.alb.security_group_id
  host_header            = "butler.${var.domain_name}"
  listener_rule_priority = 200
  health_check_path      = "/healthz"

  tags = local.common_tags
}

module "ecs_service_admin_mcp" {
  source = "../../modules/ecs-service"

  service_name   = "admin-mcp"
  environment    = var.environment
  cluster_id     = module.ecs_cluster.cluster_id
  image_url      = local.service_image_urls["admin-mcp"]
  container_port = 8080
  cpu            = local.task_sizing["admin-mcp"].cpu
  memory         = local.task_sizing["admin-mcp"].memory
  desired_count  = 1

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  secret_arns = {
    DATABASE_URL    = module.secrets.secret_arns["db-master-password"]
    JWT_SIGNING_KEY = module.secrets.secret_arns["jwt-signing-key"]
  }

  env_vars = {
    NODE_ENV = "production"
  }

  load_balancer_enabled  = true
  alb_https_listener_arn = module.alb.https_listener_arn
  alb_security_group_id  = module.alb.security_group_id
  host_header            = "admin.${var.domain_name}"
  listener_rule_priority = 300
  health_check_path      = "/healthz"

  tags = local.common_tags
}

# ---- Worker services ----

module "ecs_service_scout" {
  source = "../../modules/ecs-service"

  service_name  = "scout"
  environment   = var.environment
  cluster_id    = module.ecs_cluster.cluster_id
  image_url     = local.service_image_urls["scout"]
  cpu           = local.task_sizing["scout"].cpu
  memory        = local.task_sizing["scout"].memory
  desired_count = 1

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  secret_arns = {
    DATABASE_URL = module.secrets.secret_arns["db-master-password"]
  }

  env_vars = {
    QUEUE_URL = module.sqs.queue_urls["scout-jobs"]
  }

  load_balancer_enabled = false

  tags = local.common_tags
}

module "ecs_service_harvester" {
  source = "../../modules/ecs-service"

  service_name  = "harvester"
  environment   = var.environment
  cluster_id    = module.ecs_cluster.cluster_id
  image_url     = local.service_image_urls["harvester"]
  cpu           = local.task_sizing["harvester"].cpu
  memory        = local.task_sizing["harvester"].memory
  desired_count = 1

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  secret_arns = {
    DATABASE_URL = module.secrets.secret_arns["db-master-password"]
  }

  env_vars = {
    QUEUE_URL = module.sqs.queue_urls["harvester-jobs"]
  }

  load_balancer_enabled = false

  tags = local.common_tags
}

module "ecs_service_profiler" {
  source = "../../modules/ecs-service"

  service_name  = "profiler"
  environment   = var.environment
  cluster_id    = module.ecs_cluster.cluster_id
  image_url     = local.service_image_urls["profiler"]
  cpu           = local.task_sizing["profiler"].cpu
  memory        = local.task_sizing["profiler"].memory
  desired_count = 1

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  secret_arns = {
    DATABASE_URL        = module.secrets.secret_arns["db-master-password"]
    PERSON_DATA_API_KEY = module.secrets.secret_arns["person-data-api-key"]
  }

  env_vars = {
    QUEUE_URL = module.sqs.queue_urls["profiler-jobs"]
  }

  load_balancer_enabled = false

  tags = local.common_tags
}

module "ecs_service_writer" {
  source = "../../modules/ecs-service"

  service_name  = "writer"
  environment   = var.environment
  cluster_id    = module.ecs_cluster.cluster_id
  image_url     = local.service_image_urls["writer"]
  cpu           = local.task_sizing["writer"].cpu
  memory        = local.task_sizing["writer"].memory
  desired_count = 1

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  secret_arns = {
    DATABASE_URL      = module.secrets.secret_arns["db-master-password"]
    JWT_SIGNING_KEY   = module.secrets.secret_arns["jwt-signing-key"]
    ANTHROPIC_API_KEY = module.secrets.secret_arns["anthropic-api-key"]
  }

  env_vars = {
    NODE_ENV  = "production"
    QUEUE_URL = module.sqs.queue_urls["writer-jobs"]
  }

  load_balancer_enabled = false

  tags = local.common_tags
}

# ---- Security services ----

module "waf" {
  source = "../../modules/waf"

  name        = "alb"
  environment = var.environment
  alb_arn     = module.alb.alb_arn

  tags = local.common_tags
}

module "guardduty" {
  source = "../../modules/guardduty"

  environment = var.environment

  tags = local.common_tags
}

module "ses" {
  source = "../../modules/ses"

  domain_name = var.domain_name
  environment = var.environment

  tags = local.common_tags
}

module "s3_artifacts" {
  source = "../../modules/s3"

  bucket_name = "${var.environment}-app-artifacts"
  environment = var.environment

  tags = local.common_tags
}

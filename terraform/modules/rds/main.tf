locals {
  base_tags = merge(
    {
      Environment = var.environment
      Project     = "ai-sales-intelligence-platform"
      ManagedBy   = "terraform"
    },
    var.tags,
  )

  full_identifier = "${var.environment}-${var.identifier}"

  generate_password = var.master_password_secret_arn == null
}

# --- DB subnet group

resource "aws_db_subnet_group" "this" {
  name        = local.full_identifier
  description = "Private subnet group for ${local.full_identifier}."
  subnet_ids  = var.db_subnet_ids

  tags = merge(local.base_tags, {
    Name = "${local.full_identifier}-subnet-group"
  })
}

# --- Security group. Ingress only from explicitly allowed SGs; no egress.

resource "aws_security_group" "this" {
  name        = "${local.full_identifier}-sg"
  description = "Allows ${var.port}/tcp from approved security groups to the DB. No egress."
  vpc_id      = var.vpc_id

  tags = merge(local.base_tags, {
    Name = "${local.full_identifier}-sg"
  })
}

resource "aws_security_group_rule" "ingress_from_allowed" {
  count                    = length(var.allowed_security_group_ids)
  type                     = "ingress"
  from_port                = var.port
  to_port                  = var.port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.this.id
  source_security_group_id = var.allowed_security_group_ids[count.index]
  description              = "DB ingress from approved security group"
}

# --- Parameter group: require TLS, enable pg_stat_statements

resource "aws_db_parameter_group" "this" {
  name        = "${local.full_identifier}-pg"
  family      = var.parameter_group_family
  description = "Parameters for ${local.full_identifier}: force TLS, enable pg_stat_statements."

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    # shared_preload_libraries requires a reboot to take effect.
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  tags = merge(local.base_tags, {
    Name = "${local.full_identifier}-pg"
  })
}

# --- Master password: either pull from the caller-supplied secret, or
#     generate one and store it in a module-managed secret.

resource "random_password" "master" {
  count            = local.generate_password ? 1 : 0
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}:?"
}

resource "aws_secretsmanager_secret" "master" {
  count                   = local.generate_password ? 1 : 0
  name                    = "/${var.environment}/${var.identifier}/master-password"
  description             = "Master password for ${local.full_identifier}. Rotate manually or via a separate rotation workflow."
  recovery_window_in_days = 7

  tags = merge(local.base_tags, {
    Name = "${local.full_identifier}-master-password"
  })
}

resource "aws_secretsmanager_secret_version" "master" {
  count         = local.generate_password ? 1 : 0
  secret_id     = aws_secretsmanager_secret.master[0].id
  secret_string = jsonencode({ username = var.master_username, password = random_password.master[0].result })
}

data "aws_secretsmanager_secret_version" "external" {
  count     = local.generate_password ? 0 : 1
  secret_id = var.master_password_secret_arn
}

locals {
  resolved_password = local.generate_password ? random_password.master[0].result : try(
    jsondecode(data.aws_secretsmanager_secret_version.external[0].secret_string).password,
    data.aws_secretsmanager_secret_version.external[0].secret_string,
  )

  master_secret_arn = local.generate_password ? aws_secretsmanager_secret.master[0].arn : var.master_password_secret_arn
}

# --- DB instance

resource "aws_db_instance" "this" {
  identifier = local.full_identifier

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage == var.allocated_storage ? null : var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_id

  db_name  = var.db_name
  username = var.master_username
  password = local.resolved_password
  port     = var.port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false

  multi_az                            = var.multi_az
  backup_retention_period             = var.backup_retention_period
  backup_window                       = "03:00-04:00"
  maintenance_window                  = "sun:04:30-sun:05:30"
  copy_tags_to_snapshot               = true
  deletion_protection                 = var.deletion_protection
  auto_minor_version_upgrade          = true
  iam_database_authentication_enabled = true

  performance_insights_enabled          = true
  performance_insights_retention_period = var.performance_insights_retention_period

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  skip_final_snapshot       = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${local.full_identifier}-final-${formatdate("YYYYMMDDhhmm", timestamp())}" : null

  lifecycle {
    ignore_changes = [
      # timestamp() re-computes on every plan; the snapshot id only matters on
      # destroy, so keep it stable after creation.
      final_snapshot_identifier,
      # When the password is sourced from an external secret, rotations happen
      # out-of-band and shouldn't show as Terraform drift.
      password,
    ]
  }

  tags = merge(local.base_tags, {
    Name = local.full_identifier
  })
}

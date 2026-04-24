locals {
  base_tags = merge(
    {
      Environment = var.environment
      Project     = "ai-sales-intelligence-platform"
      ManagedBy   = "terraform"
    },
    var.tags,
  )
}

resource "aws_secretsmanager_secret" "this" {
  for_each = var.secrets

  name                    = "${var.path_prefix}/${var.environment}/${each.key}"
  description             = each.value
  recovery_window_in_days = var.recovery_window_in_days
  kms_key_id              = var.kms_key_id

  tags = merge(local.base_tags, {
    Name   = "${var.path_prefix}/${var.environment}/${each.key}"
    Secret = each.key
  })
}

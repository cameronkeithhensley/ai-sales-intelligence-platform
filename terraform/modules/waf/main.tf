locals {
  base_tags = merge(
    {
      Environment = var.environment
      Project     = "ai-sales-intelligence-platform"
      ManagedBy   = "terraform"
    },
    var.tags,
  )

  full_name = "${var.environment}-${var.name}-waf"
  log_group = "aws-waf-logs-${var.environment}-${var.name}"
}

# --- Web ACL

resource "aws_wafv2_web_acl" "this" {
  name  = local.full_name
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # --- AWS managed rule groups (dynamic over the variable so callers can
  #     swap or add groups without editing the module).
  dynamic "rule" {
    for_each = var.managed_rule_groups
    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = "AWS"

          dynamic "rule_action_override" {
            for_each = rule.value.excluded_rules
            content {
              name = rule_action_override.value
              action_to_use {
                count {}
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.metric_name
        sampled_requests_enabled   = true
      }
    }
  }

  # --- Rate-based rule.

  rule {
    name     = "RateLimitPerIp"
    priority = 100

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit_per_5min
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitPerIp"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = local.full_name
    sampled_requests_enabled   = true
  }

  tags = merge(local.base_tags, {
    Name = local.full_name
  })
}

# --- Association to the ALB

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

# --- Logging

resource "aws_cloudwatch_log_group" "waf" {
  # aws_wafv2_web_acl_logging_configuration requires the log group name to
  # begin with "aws-waf-logs-".
  name              = local.log_group
  retention_in_days = var.log_retention_days

  tags = merge(local.base_tags, {
    Name = local.log_group
  })
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.this.arn

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }

  redacted_fields {
    single_header {
      name = "x-api-key"
    }
  }
}

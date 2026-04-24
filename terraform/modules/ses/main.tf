locals {
  base_tags = merge(
    {
      Environment = var.environment
      Project     = "ai-sales-intelligence-platform"
      ManagedBy   = "terraform"
    },
    var.tags,
  )

  mail_from_domain = "${var.mail_from_subdomain}.${var.domain_name}"
  config_set_name  = coalesce(var.configuration_set_name, "${var.environment}-transactional")
}

# --- Domain identity

resource "aws_ses_domain_identity" "this" {
  domain = var.domain_name
}

resource "aws_ses_domain_dkim" "this" {
  domain = aws_ses_domain_identity.this.domain
}

resource "aws_ses_domain_mail_from" "this" {
  domain                 = aws_ses_domain_identity.this.domain
  mail_from_domain       = local.mail_from_domain
  behavior_on_mx_failure = "RejectMessage"
}

# --- Configuration set (SES v2)

resource "aws_sesv2_configuration_set" "this" {
  configuration_set_name = local.config_set_name

  reputation_options {
    reputation_metrics_enabled = true
  }

  sending_options {
    sending_enabled = true
  }

  delivery_options {
    tls_policy = var.tls_policy
  }

  tags = merge(local.base_tags, {
    Name = local.config_set_name
  })
}

resource "aws_sesv2_configuration_set_event_destination" "cloudwatch" {
  configuration_set_name = aws_sesv2_configuration_set.this.configuration_set_name
  event_destination_name = "cloudwatch-metrics"

  event_destination {
    enabled = true

    matching_event_types = [
      "SEND",
      "DELIVERY",
      "BOUNCE",
      "COMPLAINT",
      "REJECT",
    ]

    cloud_watch_destination {
      dimension_configuration {
        dimension_name          = "environment"
        dimension_value_source  = "MESSAGE_TAG"
        default_dimension_value = var.environment
      }
    }
  }
}

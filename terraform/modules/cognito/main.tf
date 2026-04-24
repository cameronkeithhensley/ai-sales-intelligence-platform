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

resource "aws_cognito_user_pool" "this" {
  name                = var.user_pool_name
  deletion_protection = var.deletion_protection
  mfa_configuration   = var.mfa_configuration

  # --- Sign-in + verification

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # --- Password policy: modern NIST-aligned defaults

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 3
  }

  # --- TOTP is preferred when MFA is enabled; SMS is not configured here
  #     because it requires an SNS role and opens a toll-fraud vector.

  dynamic "software_token_mfa_configuration" {
    for_each = var.mfa_configuration == "OFF" ? [] : [1]
    content {
      enabled = true
    }
  }

  # --- Account recovery: email only (no SMS; same reasoning)

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  email_configuration {
    # Falls back to the Cognito-default sender; production should swap in a
    # real SES configuration set ARN.
    email_sending_account = "COGNITO_DEFAULT"
  }

  # --- Protect against common attacks at the pool level

  user_pool_add_ons {
    advanced_security_mode = "AUDIT"
  }

  schema {
    name                     = "email"
    attribute_data_type      = "String"
    mutable                  = true
    required                 = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 5
      max_length = 256
    }
  }

  # --- Custom tenant_id attribute. The app resolves Cognito sub -> tenants
  #     table -> schema_name (see ARCHITECTURE.md §5); this attribute is an
  #     optional cache slot for that mapping if the app ever wants to avoid
  #     the extra lookup on the hot path.
  schema {
    name                     = "tenant_id"
    attribute_data_type      = "String"
    mutable                  = true
    required                 = false
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 64
    }
  }

  tags = merge(local.base_tags, {
    Name = var.user_pool_name
  })
}

resource "aws_cognito_user_pool_domain" "this" {
  domain       = var.domain_prefix
  user_pool_id = aws_cognito_user_pool.this.id
}

resource "aws_cognito_user_pool_client" "this" {
  name         = var.client_name
  user_pool_id = aws_cognito_user_pool.this.id

  # Confidential client: generate a client secret. Server-side token handling.
  generate_secret = true

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "profile", "email"]

  callback_urls = var.callback_urls
  logout_urls   = var.logout_urls

  supported_identity_providers = ["COGNITO"]

  # Disable legacy USER_PASSWORD_AUTH; require SRP or refresh.
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  prevent_user_existence_errors = "ENABLED"

  # Token lifetimes
  access_token_validity  = var.access_token_validity_minutes
  id_token_validity      = var.id_token_validity_minutes
  refresh_token_validity = var.refresh_token_validity_days

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

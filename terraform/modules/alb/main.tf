locals {
  base_tags = merge(
    {
      Environment = var.environment
      Project     = "ai-sales-intelligence-platform"
      ManagedBy   = "terraform"
    },
    var.tags,
  )

  full_name = "${var.environment}-${var.name}"
}

# --- Security group. 80/443 from the internet; egress anywhere inside the VPC.

resource "aws_security_group" "this" {
  name        = "${local.full_name}-alb-sg"
  description = "ALB SG: HTTP/HTTPS from the internet, egress to task targets."
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP (redirected to HTTPS by the listener)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Intentional "any port, any host in VPC" egress — target groups listen on
  # a mix of ports across tasks. Finer rules are the target SGs' job.
  egress {
    description = "All outbound inside the VPC (to target SGs)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.base_tags, {
    Name = "${local.full_name}-alb-sg"
  })
}

# --- ALB

resource "aws_lb" "this" {
  name                       = local.full_name
  load_balancer_type         = "application"
  internal                   = false
  subnets                    = var.public_subnet_ids
  security_groups            = [aws_security_group.this.id]
  idle_timeout               = var.idle_timeout
  enable_deletion_protection = var.enable_deletion_protection
  drop_invalid_header_fields = var.drop_invalid_header_fields

  dynamic "access_logs" {
    for_each = var.access_logs_bucket == null ? [] : [1]
    content {
      bucket  = var.access_logs_bucket
      prefix  = var.access_logs_prefix
      enabled = true
    }
  }

  tags = merge(local.base_tags, {
    Name = local.full_name
  })
}

# --- HTTP -> HTTPS redirect

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(local.base_tags, {
    Name = "${local.full_name}-http-listener"
  })
}

# --- HTTPS listener. Default action returns 404 so that unrouted hosts do
#     not leak anything useful. Target groups are added in Sprint 2 via
#     aws_lb_listener_rule resources outside this module.

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: unknown host"
      status_code  = "404"
    }
  }

  tags = merge(local.base_tags, {
    Name = "${local.full_name}-https-listener"
  })
}

resource "aws_lb_listener_certificate" "additional" {
  for_each = toset(var.additional_certificate_arns)

  listener_arn    = aws_lb_listener.https.arn
  certificate_arn = each.value
}

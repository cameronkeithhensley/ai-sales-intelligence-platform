locals {
  base_tags = merge(
    {
      Environment = var.environment
      Project     = "ai-sales-intelligence-platform"
      ManagedBy   = "terraform"
      Service     = var.service_name
    },
    var.tags,
  )

  full_name       = "${var.environment}-${var.service_name}"
  log_group_name  = "/ecs/${var.environment}/${var.service_name}"
  container_name  = var.service_name
  task_def_family = local.full_name

  env_list = [
    for k, v in var.env_vars : { name = k, value = v }
  ]

  secret_list = [
    for k, v in var.secret_arns : { name = k, valueFrom = v }
  ]

  container_definition = [{
    name      = local.container_name
    image     = var.image_url
    essential = true
    portMappings = [{
      containerPort = var.container_port
      hostPort      = var.container_port
      protocol      = "tcp"
    }]
    environment = local.env_list
    secrets     = local.secret_list
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = local.log_group_name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = var.service_name
      }
    }
    readonlyRootFilesystem = false
  }]
}

data "aws_region" "current" {}

# --- CloudWatch Logs group

resource "aws_cloudwatch_log_group" "this" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days

  tags = merge(local.base_tags, {
    Name = local.log_group_name
  })
}

# --- Service security group

resource "aws_security_group" "this" {
  name        = "${local.full_name}-sg"
  description = "Service SG for ${local.full_name}. ALB-ingress only when load-balanced; no public ingress."
  vpc_id      = var.vpc_id

  egress {
    description = "All outbound (reaches VPC endpoints, NAT, and by extension AWS APIs)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.base_tags, {
    Name = "${local.full_name}-sg"
  })
}

resource "aws_security_group_rule" "alb_ingress" {
  count                    = var.load_balancer_enabled ? 1 : 0
  type                     = "ingress"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.this.id
  source_security_group_id = var.alb_security_group_id
  description              = "ALB to service on container port"
}

# --- Task execution role: ECR pulls, Secrets Manager reads, log writes.

data "aws_iam_policy_document" "ecs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${local.full_name}-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json

  tags = merge(local.base_tags, {
    Name = "${local.full_name}-exec"
  })
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "secrets_read" {
  count = length(var.secret_arns) > 0 ? 1 : 0

  statement {
    sid       = "GetSecretsForContainerStartup"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [for _, arn in var.secret_arns : arn]
  }
}

resource "aws_iam_role_policy" "secrets_read" {
  count  = length(var.secret_arns) > 0 ? 1 : 0
  name   = "secrets-read"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.secrets_read[0].json
}

# --- Task role: per-service least privilege. Starts with logs-only.

data "aws_iam_policy_document" "task_base" {
  statement {
    sid    = "CloudWatchLogsWrite"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }
}

resource "aws_iam_role" "task" {
  name               = "${local.full_name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json

  tags = merge(local.base_tags, {
    Name = "${local.full_name}-task"
  })
}

resource "aws_iam_role_policy" "task_base" {
  name   = "base"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_base.json
}

resource "aws_iam_role_policy_attachment" "task_extra" {
  count      = length(var.additional_task_role_policy_arns)
  role       = aws_iam_role.task.name
  policy_arn = var.additional_task_role_policy_arns[count.index]
}

# --- Task definition

resource "aws_ecs_task_definition" "this" {
  family                   = local.task_def_family
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode(local.container_definition)

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  tags = merge(local.base_tags, {
    Name = local.task_def_family
  })
}

# --- Target group + listener rule (load-balanced path only)

resource "aws_lb_target_group" "this" {
  count = var.load_balancer_enabled ? 1 : 0

  # Name is capped at 32 chars by AWS.
  name        = substr("${local.full_name}-tg", 0, 32)
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  deregistration_delay = var.deregistration_delay_seconds

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }

  tags = merge(local.base_tags, {
    Name = substr("${local.full_name}-tg", 0, 32)
  })
}

resource "aws_lb_listener_rule" "this" {
  count = var.load_balancer_enabled ? 1 : 0

  listener_arn = var.alb_https_listener_arn
  priority     = var.listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[0].arn
  }

  dynamic "condition" {
    for_each = var.host_header == null ? [] : [var.host_header]
    content {
      host_header {
        values = [condition.value]
      }
    }
  }

  dynamic "condition" {
    for_each = length(var.path_patterns) == 0 ? [] : [var.path_patterns]
    content {
      path_pattern {
        values = condition.value
      }
    }
  }

  tags = merge(local.base_tags, {
    Name = "${local.full_name}-rule"
  })
}

# --- ECS service

resource "aws_ecs_service" "this" {
  name            = var.service_name
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = length(var.capacity_provider_strategy) == 0 ? "FARGATE" : null

  enable_execute_command = var.enable_execute_command

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.this.id]
    assign_public_ip = var.assign_public_ip
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50

  health_check_grace_period_seconds = var.load_balancer_enabled ? var.health_check_grace_period_seconds : null

  dynamic "load_balancer" {
    for_each = var.load_balancer_enabled ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.this[0].arn
      container_name   = local.container_name
      container_port   = var.container_port
    }
  }

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategy
    content {
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = capacity_provider_strategy.value.weight
      base              = capacity_provider_strategy.value.base
    }
  }

  lifecycle {
    ignore_changes = [
      # desired_count can drift via application autoscaling; don't bounce
      # tasks on every apply.
      desired_count,
    ]
  }

  tags = merge(local.base_tags, {
    Name = var.service_name
  })

  depends_on = [aws_lb_listener_rule.this]
}

locals {
  base_tags = merge(
    {
      Environment = var.environment
      Project     = "ai-sales-intelligence-platform"
      ManagedBy   = "terraform"
    },
    var.tags,
  )

  nat_count = var.multi_nat_enabled ? var.az_count : 1
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.base_tags, {
    Name = "${var.environment}-vpc"
  })
}

resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.base_tags, {
    Name = "${var.environment}-public-${data.aws_availability_zones.available.names[count.index]}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(local.base_tags, {
    Name = "${var.environment}-private-${data.aws_availability_zones.available.names[count.index]}"
    Tier = "private"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.base_tags, {
    Name = "${var.environment}-igw"
  })
}

resource "aws_eip" "nat" {
  count  = local.nat_count
  domain = "vpc"

  tags = merge(local.base_tags, {
    Name = "${var.environment}-nat-eip-${count.index}"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count         = local.nat_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.base_tags, {
    Name = "${var.environment}-nat-${count.index}"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.base_tags, {
    Name = "${var.environment}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = local.nat_count
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = merge(local.base_tags, {
    Name = "${var.environment}-private-rt-${count.index}"
  })
}

resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.multi_nat_enabled ? count.index : 0].id
}

# --- VPC endpoints: keep AWS-bound traffic off the public internet and
#     cut NAT egress cost for S3 + ECR pulls + secret reads + SQS polling.

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.environment}-vpce-sg"
  description = "Allows HTTPS from inside the VPC to interface VPC endpoints."
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from inside the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.base_tags, {
    Name = "${var.environment}-vpce-sg"
  })
}

data "aws_region" "current" {}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id

  tags = merge(local.base_tags, {
    Name = "${var.environment}-vpce-s3"
  })
}

locals {
  interface_endpoint_services = toset(["ecr.api", "ecr.dkr", "secretsmanager", "sqs"])
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoint_services

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.base_tags, {
    Name = "${var.environment}-vpce-${each.value}"
  })
}

# --- Flow logs

resource "aws_cloudwatch_log_group" "flow_logs" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/aws/vpc/${var.environment}/flow-logs"
  retention_in_days = var.flow_logs_retention_days

  tags = merge(local.base_tags, {
    Name = "${var.environment}-flow-logs"
  })
}

data "aws_iam_policy_document" "flow_logs_assume" {
  count = var.enable_flow_logs ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "flow_logs_publish" {
  count = var.enable_flow_logs ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.flow_logs[0].arn}:*"]
  }
}

resource "aws_iam_role" "flow_logs" {
  count              = var.enable_flow_logs ? 1 : 0
  name               = "${var.environment}-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume[0].json

  tags = merge(local.base_tags, {
    Name = "${var.environment}-vpc-flow-logs-role"
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  count  = var.enable_flow_logs ? 1 : 0
  name   = "${var.environment}-vpc-flow-logs-publish"
  role   = aws_iam_role.flow_logs[0].id
  policy = data.aws_iam_policy_document.flow_logs_publish[0].json
}

resource "aws_flow_log" "this" {
  count                = var.enable_flow_logs ? 1 : 0
  iam_role_arn         = aws_iam_role.flow_logs[0].arn
  log_destination      = aws_cloudwatch_log_group.flow_logs[0].arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.this.id

  tags = merge(local.base_tags, {
    Name = "${var.environment}-flow-logs"
  })
}

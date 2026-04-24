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

  user_data = <<-EOT
    #!/bin/bash
    set -euxo pipefail
    dnf -y update
    # postgresql15 covers psql + pg_dump for migrations against the RDS instance.
    dnf -y install postgresql15
    ${var.user_data_extra}
  EOT
}

# --- Latest Amazon Linux 2023 AMI

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- Security group. SSM is agent-initiated outbound; no inbound rules.

resource "aws_security_group" "this" {
  name        = "${local.full_name}-sg"
  description = "Bastion SG: no inbound (SSM is outbound-initiated); egress HTTPS + VPC for admin access."
  vpc_id      = var.vpc_id

  egress {
    description = "HTTPS to AWS endpoints (SSM, Secrets Manager, ECR, etc.)."
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "PostgreSQL to RDS (reachability is governed by the RDS SG allowlist)."
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.base_tags, {
    Name = "${local.full_name}-sg"
  })
}

# --- IAM role / instance profile for SSM Session Manager

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${local.full_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = merge(local.base_tags, {
    Name = "${local.full_name}-role"
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "extra" {
  count      = length(var.additional_iam_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = var.additional_iam_policy_arns[count.index]
}

resource "aws_iam_instance_profile" "this" {
  name = "${local.full_name}-profile"
  role = aws_iam_role.this.name

  tags = merge(local.base_tags, {
    Name = "${local.full_name}-profile"
  })
}

# --- EC2 instance

resource "aws_instance" "this" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = concat([aws_security_group.this.id], var.additional_security_group_ids)
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = false
  user_data                   = local.user_data
  monitoring                  = true

  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
    kms_key_id  = var.kms_key_id
  }

  tags = merge(local.base_tags, {
    Name = local.full_name
  })

  volume_tags = merge(local.base_tags, {
    Name = "${local.full_name}-root"
  })

  lifecycle {
    ignore_changes = [
      # Terraform shouldn't replace the instance every time Amazon rolls a new
      # AMI; operators can taint it to force a refresh.
      ami,
      user_data,
    ]
  }
}

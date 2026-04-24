aws_account_id = "000000000000"
aws_region     = "us-east-1"
environment    = "dev"
domain_name    = "dev.example.com"

vpc_cidr             = "10.20.0.0/16"
az_count             = 2
public_subnet_cidrs  = ["10.20.0.0/24", "10.20.1.0/24"]
private_subnet_cidrs = ["10.20.10.0/24", "10.20.11.0/24"]
multi_nat_enabled    = false

rds_instance_class      = "db.t3.micro"
rds_allocated_storage   = 20
rds_multi_az            = false
rds_deletion_protection = false

bastion_instance_type = "t3.micro"

alb_certificate_arn   = "arn:aws:acm:us-east-1:000000000000:certificate/00000000-0000-0000-0000-000000000000"
cognito_domain_prefix = "ai-sip-dev"

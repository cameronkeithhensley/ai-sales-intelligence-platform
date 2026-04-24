output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, ordered by AZ index."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets, ordered by AZ index."
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the internet gateway attached to the VPC."
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateway(s). One element when multi_nat_enabled is false; one per AZ otherwise."
  value       = aws_nat_gateway.this[*].id
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "IDs of the private route table(s)."
  value       = aws_route_table.private[*].id
}

output "vpc_endpoint_ids" {
  description = "Map of VPC endpoint service shortname → endpoint ID. Keys: s3, ecr.api, ecr.dkr, secretsmanager, sqs."
  value = merge(
    { "s3" = aws_vpc_endpoint.s3.id },
    { for k, v in aws_vpc_endpoint.interface : k => v.id },
  )
}

output "vpc_endpoints_security_group_id" {
  description = "Security group ID attached to the interface VPC endpoints."
  value       = aws_security_group.vpc_endpoints.id
}

output "flow_logs_log_group_name" {
  description = "CloudWatch log group name for VPC flow logs (null if flow logs are disabled)."
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].name : null
}

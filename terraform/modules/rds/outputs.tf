output "endpoint" {
  description = "Connection endpoint (host:port) of the DB instance."
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "Hostname of the DB instance."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Port the DB instance listens on."
  value       = aws_db_instance.this.port
}

output "db_instance_arn" {
  description = "ARN of the DB instance."
  value       = aws_db_instance.this.arn
}

output "db_instance_id" {
  description = "Identifier of the DB instance."
  value       = aws_db_instance.this.id
}

output "db_instance_resource_id" {
  description = "DbiResourceId of the DB instance. Required for IAM database auth policy statements."
  value       = aws_db_instance.this.resource_id
}

output "security_group_id" {
  description = "Security group ID controlling ingress to the DB. Source security groups (e.g. ECS task SG) must be added to allowed_security_group_ids rather than by reaching into this SG directly."
  value       = aws_security_group.this.id
}

output "subnet_group_name" {
  description = "Name of the DB subnet group."
  value       = aws_db_subnet_group.this.name
}

output "parameter_group_name" {
  description = "Name of the DB parameter group."
  value       = aws_db_parameter_group.this.name
}

output "master_password_secret_arn" {
  description = "Secrets Manager ARN holding the master credentials. Consumer of this output should read the secret at runtime rather than receiving the password via a plaintext variable."
  value       = local.master_secret_arn
}

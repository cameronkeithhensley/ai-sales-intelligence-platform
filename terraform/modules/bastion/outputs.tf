output "instance_id" {
  description = "EC2 instance ID. Start a session with: aws ssm start-session --target <instance_id>."
  value       = aws_instance.this.id
}

output "security_group_id" {
  description = "Security group ID attached to the bastion. Add this as a source SG on the RDS allowlist."
  value       = aws_security_group.this.id
}

output "iam_role_arn" {
  description = "ARN of the bastion IAM role. Attach additional policies via additional_iam_policy_arns rather than editing the role directly."
  value       = aws_iam_role.this.arn
}

output "iam_role_name" {
  description = "Name of the bastion IAM role."
  value       = aws_iam_role.this.name
}

output "iam_instance_profile_name" {
  description = "Name of the bastion's EC2 instance profile."
  value       = aws_iam_instance_profile.this.name
}

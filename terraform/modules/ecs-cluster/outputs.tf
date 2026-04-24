output "cluster_id" {
  description = "ID of the ECS cluster."
  value       = aws_ecs_cluster.this.id
}

output "cluster_arn" {
  description = "ARN of the ECS cluster. Pass this to the ecs-service module as cluster_id (the resource accepts either the id or ARN)."
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster. Used in IAM policy resource matchers and in the console."
  value       = aws_ecs_cluster.this.name
}

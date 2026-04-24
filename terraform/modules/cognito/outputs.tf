output "user_pool_id" {
  description = "ID of the Cognito user pool."
  value       = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  description = "ARN of the Cognito user pool. Use this in an ALB listener rule authenticate-cognito action and in API Gateway authorizers."
  value       = aws_cognito_user_pool.this.arn
}

output "user_pool_endpoint" {
  description = "Issuer endpoint for the user pool (cognito-idp.<region>.amazonaws.com/<pool_id>). OIDC relying parties use this as the issuer."
  value       = aws_cognito_user_pool.this.endpoint
}

output "user_pool_client_id" {
  description = "ID of the confidential user pool client."
  value       = aws_cognito_user_pool_client.this.id
}

output "user_pool_client_secret" {
  description = "Client secret for the confidential user pool client. Sensitive — do not log, and store in Secrets Manager when consumed by a service."
  value       = aws_cognito_user_pool_client.this.client_secret
  sensitive   = true
}

output "user_pool_domain" {
  description = "Cognito hosted-UI domain (the prefix form; full URL is https://{domain}.auth.<region>.amazoncognito.com)."
  value       = aws_cognito_user_pool_domain.this.domain
}

output "domain_identity_arn" {
  description = "ARN of the SES domain identity."
  value       = aws_ses_domain_identity.this.arn
}

output "domain" {
  description = "The SES domain identity."
  value       = aws_ses_domain_identity.this.domain
}

output "dkim_tokens" {
  description = "DKIM tokens (3 strings) to publish as CNAME records: <token>._domainkey.<domain> CNAME <token>.dkim.amazonses.com. DNS management lives outside this repo."
  value       = aws_ses_domain_dkim.this.dkim_tokens
}

output "mail_from_domain" {
  description = "The MAIL FROM (SMTP envelope-from) domain. Publish an MX record <mail_from_domain> -> feedback-smtp.<region>.amazonses.com and an SPF TXT record."
  value       = aws_ses_domain_mail_from.this.mail_from_domain
}

output "configuration_set_name" {
  description = "Configuration set name. Applications should pass this via the SES SendEmail / SendRawEmail 'ConfigurationSetName' parameter to get reputation metrics + event publishing."
  value       = aws_sesv2_configuration_set.this.configuration_set_name
}

output "configuration_set_arn" {
  description = "Configuration set ARN."
  value       = aws_sesv2_configuration_set.this.arn
}

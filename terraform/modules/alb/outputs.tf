output "alb_arn" {
  description = "ARN of the application load balancer."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB. Use this as the target of a Route 53 ALIAS record pointing at the domain you want to publish."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID for the ALB. Required for the Route 53 ALIAS alias_target block."
  value       = aws_lb.this.zone_id
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener. Attach aws_lb_listener_rule resources to this to route traffic to target groups."
  value       = aws_lb_listener.https.arn
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener (which only does the 301 redirect to HTTPS). Exposed for completeness; you rarely want to attach rules here."
  value       = aws_lb_listener.http.arn
}

output "security_group_id" {
  description = "Security group ID attached to the ALB. Task / service SGs should permit ingress from this SG on their listen port."
  value       = aws_security_group.this.id
}

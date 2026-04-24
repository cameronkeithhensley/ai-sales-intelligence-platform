output "detector_id" {
  description = "ID of the GuardDuty detector. Use this when attaching EventBridge rules to filter findings by severity."
  value       = aws_guardduty_detector.this.id
}

output "detector_arn" {
  description = "ARN of the GuardDuty detector."
  value       = aws_guardduty_detector.this.arn
}

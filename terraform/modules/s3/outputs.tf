output "bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = aws_s3_bucket.this.arn
}

output "bucket_id" {
  description = "ID (name) of the S3 bucket."
  value       = aws_s3_bucket.this.id
}

output "bucket_regional_domain_name" {
  description = "Regional S3 bucket domain name. Use this as an ALIAS target (or CloudFront origin) rather than the bucket_domain_name global form, to avoid request routing delays during bucket provisioning."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "bucket_domain_name" {
  description = "Global S3 bucket domain name. Prefer bucket_regional_domain_name for most uses."
  value       = aws_s3_bucket.this.bucket_domain_name
}

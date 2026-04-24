locals {
  base_tags = merge(
    {
      Environment = var.environment
      Project     = "ai-sales-intelligence-platform"
      ManagedBy   = "terraform"
    },
    var.tags,
  )
}

resource "aws_guardduty_detector" "this" {
  enable                       = true
  finding_publishing_frequency = var.finding_publishing_frequency

  tags = merge(local.base_tags, {
    Name = "${var.environment}-guardduty"
  })
}

# --- Feature toggles. Kept as separate resources so enabling / disabling
#     one does not force recreation of the detector.

resource "aws_guardduty_detector_feature" "s3_logs" {
  detector_id = aws_guardduty_detector.this.id
  name        = "S3_DATA_EVENTS"
  status      = var.enable_s3_logs ? "ENABLED" : "DISABLED"
}

resource "aws_guardduty_detector_feature" "lambda_network_logs" {
  detector_id = aws_guardduty_detector.this.id
  name        = "LAMBDA_NETWORK_LOGS"
  status      = var.enable_lambda_logs ? "ENABLED" : "DISABLED"
}

resource "aws_guardduty_detector_feature" "eks_audit_logs" {
  # EKS is not used in this architecture; the resource is declared so the
  # default state (DISABLED) is explicit and visible in state rather than
  # silently absent.
  detector_id = aws_guardduty_detector.this.id
  name        = "EKS_AUDIT_LOGS"
  status      = var.enable_eks_audit_logs ? "ENABLED" : "DISABLED"
}

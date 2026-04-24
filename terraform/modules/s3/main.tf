locals {
  base_tags = merge(
    {
      Environment = var.environment
      Project     = "ai-sales-intelligence-platform"
      ManagedBy   = "terraform"
    },
    var.tags,
  )

  use_kms = var.kms_key_arn != null
}

# --- Bucket

resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = merge(local.base_tags, {
    Name = var.bucket_name
  })
}

# --- Public access block. All four flags on.

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Ownership: disable ACLs entirely.

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# --- Encryption

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.use_kms ? "aws:kms" : "AES256"
      kms_master_key_id = local.use_kms ? var.kms_key_arn : null
    }

    bucket_key_enabled = local.use_kms
  }
}

# --- Versioning

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# --- Lifecycle

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  depends_on = [aws_s3_bucket_versioning.this]

  rule {
    id     = "noncurrent-version-management"
    status = var.versioning_enabled ? "Enabled" : "Disabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = var.noncurrent_version_transition_days
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = var.incomplete_multipart_upload_days
    }
  }
}

# --- TLS-only bucket policy.

data "aws_iam_policy_document" "tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket     = aws_s3_bucket.this.id
  policy     = data.aws_iam_policy_document.tls_only.json
  depends_on = [aws_s3_bucket_public_access_block.this]
}

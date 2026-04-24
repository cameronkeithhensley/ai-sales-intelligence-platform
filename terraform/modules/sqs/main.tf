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

resource "aws_sqs_queue" "dlq" {
  for_each = var.queues

  name                      = "${var.environment}-${each.key}-dlq"
  message_retention_seconds = var.dlq_message_retention_seconds
  kms_master_key_id         = var.kms_master_key_id

  tags = merge(local.base_tags, {
    Name  = "${var.environment}-${each.key}-dlq"
    Queue = each.key
    Role  = "dlq"
  })
}

resource "aws_sqs_queue" "main" {
  for_each = var.queues

  name                       = "${var.environment}-${each.key}"
  visibility_timeout_seconds = each.value.visibility_timeout_seconds
  message_retention_seconds  = each.value.message_retention_seconds
  kms_master_key_id          = var.kms_master_key_id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[each.key].arn
    maxReceiveCount     = each.value.max_receive_count
  })

  tags = merge(local.base_tags, {
    Name  = "${var.environment}-${each.key}"
    Queue = each.key
    Role  = "main"
  })
}

# Re-drive allowance: only the matching main queue may send messages back to
# its own DLQ via SQS start-message-move operations. Closes the "any principal
# may move messages off my DLQ" hole that exists by default.
resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  for_each  = var.queues
  queue_url = aws_sqs_queue.dlq[each.key].id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.main[each.key].arn]
  })
}

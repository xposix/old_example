resource "aws_sqs_queue" "incoming_requests" {
  name                      = "${var.environment_name}-client-app-incoming-requests"
  max_message_size          = 262144 # 256 KiB
  message_retention_seconds = 345600 # 4 days
  receive_wait_time_seconds = 10
  # redrive_policy = jsonencode({
  #   deadLetterTargetArn = aws_sqs_queue.terraform_queue_deadletter.arn
  #   maxReceiveCount     = 4
  # })

  kms_master_key_id                 = data.aws_kms_key.clz_kms_key.id
  kms_data_key_reuse_period_seconds = 300

  tags = local.project_tags
}

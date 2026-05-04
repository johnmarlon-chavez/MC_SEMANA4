resource "aws_s3_bucket" "images" {
  bucket = "${var.project_name}-${var.environment}-images-upao-marlonchavez"
  tags   = { Owner = "MarlonChavez" }
}

resource "aws_s3_bucket_lifecycle_configuration" "images_lifecycle" {
  bucket = aws_s3_bucket.images.id

  rule {
    id     = "expire-uploads"
    status = "Enabled"
    filter { prefix = "uploads/" }
    expiration { days = 30 }
  }

  rule {
    id     = "expire-processed"
    status = "Enabled"
    filter { prefix = "processed/" }
    expiration { days = 90 }
  }
}

resource "aws_sqs_queue" "image_dlq" {
  name                      = "${var.project_name}-${var.environment}-image-dlq"
  message_retention_seconds = 1209600 
  tags = { Owner = "MarlonChavez" }
}

resource "aws_sqs_queue" "image_queue" {
  name                       = "${var.project_name}-${var.environment}-image-queue"
  visibility_timeout_seconds = 360 
  message_retention_seconds  = 86400 
  receive_wait_time_seconds  = 20    

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.image_dlq.arn
    maxReceiveCount     = 3 
  })
  tags = { Owner = "MarlonChavez" }
}

resource "aws_sqs_queue_policy" "allow_s3_events" {
  queue_url = aws_sqs_queue.image_queue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.image_queue.arn
      Condition = {
        ArnLike = { "aws:SourceArn" : aws_s3_bucket.images.arn }
      }
    }]
  })
}

resource "aws_s3_bucket_notification" "s3_notif" {
  bucket = aws_s3_bucket.images.id

  queue {
    queue_arn     = aws_sqs_queue.image_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "uploads/" 
  }

  depends_on = [aws_sqs_queue_policy.allow_s3_events]
}
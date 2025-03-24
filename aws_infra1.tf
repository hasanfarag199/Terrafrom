terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"  # London region, equivalent to West Europe
}

# Create an S3 bucket for file uploads
resource "aws_s3_bucket" "upload_bucket" {
  bucket = "upload-storage-bucket"
}

# Enable versioning for the bucket
resource "aws_s3_bucket_versioning" "upload_bucket_versioning" {
  bucket = aws_s3_bucket.upload_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Create an SQS queue for processing uploads
resource "aws_sqs_queue" "upload_queue" {
  name = "upload-queue"
}

# Create an SQS queue policy to allow S3 to send messages
resource "aws_sqs_queue_policy" "upload_queue_policy" {
  queue_url = aws_sqs_queue.upload_queue.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.upload_queue.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn": aws_s3_bucket.upload_bucket.arn
          }
        }
      }
    ]
  })
}

# Create S3 bucket notification to trigger SQS when files are uploaded
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.upload_bucket.id

  queue {
    queue_arn     = aws_sqs_queue.upload_queue.arn
    events        = ["s3:ObjectCreated:*"]
  }
} 
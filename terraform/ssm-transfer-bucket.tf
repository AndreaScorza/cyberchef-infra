# Scratch bucket the aws_ssm Ansible connection plugin uses to shuttle
# module code to/from the instance. It's transient by nature (objects are
# deleted right after each transfer), so a short lifecycle expiration is
# enough - no versioning needed.

resource "aws_s3_bucket" "ssm_transfer" {
  bucket = "${var.project_name}-ssm-transfer-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "ssm_transfer" {
  bucket = aws_s3_bucket.ssm_transfer.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ssm_transfer" {
  bucket = aws_s3_bucket.ssm_transfer.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "ssm_transfer" {
  bucket = aws_s3_bucket.ssm_transfer.id

  rule {
    id     = "expire-transfer-objects"
    status = "Enabled"

    filter {}

    expiration {
      days = 1
    }
  }
}

# The instance's own role needs this - the SSM agent running on the box is
# what actually reads/writes the transfer objects, not just the CI role.
resource "aws_iam_role_policy" "cyberchef_ssm_transfer_bucket" {
  name = "cyberchef-ssm-transfer-bucket"
  role = aws_iam_role.cyberchef.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListSsmTransferBucket"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.ssm_transfer.arn
      },
      {
        Sid    = "ReadWriteSsmTransferObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = "${aws_s3_bucket.ssm_transfer.arn}/*"
      },
    ]
  })
}

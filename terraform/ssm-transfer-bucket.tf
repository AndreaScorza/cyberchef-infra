# Scratch bucket the aws_ssm Ansible connection plugin uses to shuttle
# module code to/from the instance. It's transient by nature (objects are
# deleted right after each transfer), so a short lifecycle expiration is
# enough - no versioning needed.

resource "aws_s3_bucket" "ssm_transfer" {
  #checkov:skip=CKV_AWS_21:Transient scratch space; objects expire after 1 day, so keeping deleted-object versions around works against the bucket's purpose.
  #checkov:skip=CKV_AWS_144:Ephemeral SSM file-transfer data with a 1-day TTL doesn't need cross-region durability.
  #checkov:skip=CKV2_AWS_62:No downstream consumer needs to react to object events in this internal scratch bucket.
  #checkov:skip=CKV_AWS_18:Access logging isn't valuable for a bucket that only ever holds transient, non-sensitive transfer blobs expiring within a day.
  #checkov:skip=CKV_AWS_145:Already encrypted at rest with SSE-S3 (AES256); customer-managed KMS adds key-management overhead with no real benefit for non-sensitive, short-lived data.
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

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }

    expiration {
      days = 1
    }
  }
}

# The instance's own role needs this - the SSM agent running on the box is
# what actually reads/writes the transfer objects, not just the CI role.
#
# Managed policy + attachment (not an inline aws_iam_role_policy) so that
# granting it to cyberchef-ssm-role goes through iam:AttachRolePolicy, which
# the CI role's own policy (oidc.tf) already restricts to a fixed allowlist
# of policy ARNs. An inline policy would instead need iam:PutRolePolicy,
# which has no equivalent way to restrict what content gets written - CI
# could inline arbitrary permissions onto this role. Same protection, no
# extra machinery.
resource "aws_iam_policy" "cyberchef_ssm_transfer_bucket" {
  name = "cyberchef-ssm-transfer-bucket"

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

resource "aws_iam_role_policy_attachment" "cyberchef_ssm_transfer_bucket" {
  role       = aws_iam_role.cyberchef.name
  policy_arn = aws_iam_policy.cyberchef_ssm_transfer_bucket.arn
}

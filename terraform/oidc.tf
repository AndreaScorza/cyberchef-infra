# The GitHub OIDC provider is a one-time, per-account bootstrap resource
# (an AWS account can only have one provider per issuer URL). It's created
# manually, not managed here, so this role's own Terraform runs never need
# IAM permissions on the provider itself. The ARN format is deterministic.
locals {
  github_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_actions" {
  #checkov:skip=CKV_AWS_393:False positive; the sub claim is pinned to immutable GitHub IDs (org@id/repo@id), which checkov's regex doesn't yet recognize as safe even though it's stricter than the name-only pattern the check expects.
  name = "cyberchef-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = local.github_oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:AndreaScorza@47422335/cyberchef-infra@1319345018:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_ec2" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "github_actions_ssm" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "github_actions_iam" {
  name = "cyberchef-github-actions-iam"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageCyberchefRole"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cyberchef-*"
      },
      {
        Sid    = "AttachKnownPoliciesToCyberchefSsmRole"
        Effect = "Allow"
        Action = [
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cyberchef-ssm-role"
        Condition = {
          ArnEquals = {
            "iam:PolicyARN" = [
              "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/cyberchef-ssm-transfer-bucket",
            ]
          }
        }
      },
      {
        Sid    = "AttachKnownPoliciesToGithubActionsRole"
        Effect = "Allow"
        Action = [
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cyberchef-github-actions"
        Condition = {
          ArnEquals = {
            "iam:PolicyARN" = [
              "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
              "arn:aws:iam::aws:policy/AmazonSSMFullAccess",
              "arn:aws:iam::aws:policy/AmazonS3FullAccess",
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/cyberchef-github-actions-iam",
            ]
          }
        }
      },
      {
        # Same action set either way, so one statement covering both
        # policy documents this role owns, rather than one near-duplicate
        # statement per policy.
        Sid    = "ManageOwnPolicyDocuments"
        Effect = "Allow"
        Action = [
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:CreatePolicy",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:DeletePolicy",
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/cyberchef-github-actions-iam",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/cyberchef-ssm-transfer-bucket",
        ]
      },
      {
        Sid    = "ManageCyberchefInstanceProfile"
        Effect = "Allow"
        Action = [
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/cyberchef-*"
      },
      {
        Sid      = "PassCyberchefRoleToEC2"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cyberchef-*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ec2.amazonaws.com"
          }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_iam" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_iam.arn
}

resource "aws_iam_role_policy_attachment" "github_actions_s3" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
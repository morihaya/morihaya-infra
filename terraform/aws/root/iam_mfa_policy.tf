# IAM Policy: Enforce MFA
# MFA未設定のユーザがMFAデバイスの設定のみ行えるよう許可し、他の操作はすべて拒否する
resource "aws_iam_policy" "enforce_mfa" {
  name        = "EnforceMFA"
  description = "Deny all actions except MFA self-management when MFA is not authenticated"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # MFA設定に必要な操作のみ許可（MFA未認証でも可）
      {
        Sid    = "AllowViewAccountInfo"
        Effect = "Allow"
        Action = [
          "iam:GetAccountPasswordPolicy",
          "iam:ListVirtualMFADevices"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowManageOwnMFA"
        Effect = "Allow"
        Action = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetUser",
          "iam:ListMFADevices",
          "iam:ResyncMFADevice"
        ]
        Resource = [
          "arn:aws:iam::*:mfa/$${aws:username}",
          "arn:aws:iam::*:user/$${aws:username}"
        ]
      },
      # MFA認証済みの場合のみ自分のMFAデバイスの削除を許可
      {
        Sid    = "AllowDeactivateOwnMFAWithMFA"
        Effect = "Allow"
        Action = [
          "iam:DeactivateMFADevice",
          "iam:DeleteVirtualMFADevice"
        ]
        Resource = [
          "arn:aws:iam::*:mfa/$${aws:username}",
          "arn:aws:iam::*:user/$${aws:username}"
        ]
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      },
      # MFA未認証の場合、上記以外のすべての操作を拒否
      {
        Sid    = "DenyAllExceptMFAManagementWithoutMFA"
        Effect = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetUser",
          "iam:GetAccountPasswordPolicy",
          "iam:ListMFADevices",
          "iam:ListVirtualMFADevices",
          "iam:ResyncMFADevice",
          "sts:GetSessionToken"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
}

# すべてのIAMユーザに適用するグループ
resource "aws_iam_group" "require_mfa" {
  name = "RequireMFA"
}

resource "aws_iam_group_policy_attachment" "require_mfa" {
  group      = aws_iam_group.require_mfa.name
  policy_arn = aws_iam_policy.enforce_mfa.arn
}

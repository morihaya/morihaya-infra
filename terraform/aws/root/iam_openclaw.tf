# IAM: OpenClaw 執事エージェント用ユーザ
# Proxmox 上の OpenClaw が Bedrock の Anthropic モデルを呼び出すための最小権限。
# アクセスキーは state に秘匿情報を残さないため Terraform では作成せず、
# apply 後にコンソールまたは CLI で手動発行する。
resource "aws_iam_user" "openclaw" {
  name = "openclaw-butler"
}

resource "aws_iam_user_policy" "openclaw_bedrock" {
  name = "BedrockInvokeMinimal"
  user = aws_iam_user.openclaw.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Anthropic モデルの呼び出し（apac.* クロスリージョン推論プロファイル経由を含む）
      {
        Sid    = "InvokeAnthropicModels"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/anthropic.*",
          "arn:aws:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/*"
        ]
      },
      # OpenClaw のモデル自動発見（bedrockDiscovery）用
      {
        Sid    = "DiscoverModels"
        Effect = "Allow"
        Action = [
          "bedrock:ListFoundationModels",
          "bedrock:GetFoundationModel",
          "bedrock:ListInferenceProfiles",
          "bedrock:GetInferenceProfile"
        ]
        Resource = "*"
      }
    ]
  })
}

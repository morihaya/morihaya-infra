module "sns_budgets" {
  source  = "terraform-aws-modules/sns/aws"
  version = "~> 3.0"

  name = "budgets"

  policy = jsonencode(
    {
      "Version" : "2008-10-17",
      "Id" : "__default_policy_ID",
      "Statement" : [
        {
          "Sid" : "__default_statement_ID",
          "Effect" : "Allow",
          "Principal" : {
            "AWS" : "*"
          },
          "Action" : [
            "SNS:GetTopicAttributes",
            "SNS:SetTopicAttributes",
            "SNS:AddPermission",
            "SNS:RemovePermission",
            "SNS:DeleteTopic",
            "SNS:Subscribe",
            "SNS:ListSubscriptionsByTopic",
            "SNS:Publish",
            "SNS:Receive"
          ],
          "Resource" : "arn:aws:sns:ap-northeast-1:${var.aws_accountid}:budgets",
          "Condition" : {
            "StringEquals" : {
              "AWS:SourceOwner" : "${var.aws_accountid}"
            }
          }
        },
        {
          "Sid" : "AWSBudgets-notification-1",
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "budgets.amazonaws.com"
          },
          "Action" : "SNS:Publish",
          "Resource" : "arn:aws:sns:ap-northeast-1:${var.aws_accountid}:budgets"
        }
      ]
    }
  )
}

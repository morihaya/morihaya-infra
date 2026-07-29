resource "aws_budgets_budget" "mybasic" {
  name              = "My Basic"
  budget_type       = "COST"
  limit_amount      = "20.0"
  limit_unit        = "USD"
  time_period_start = "2021-10-01_00:00"
  time_unit         = "MONTHLY"


  notification {
    comparison_operator = "GREATER_THAN"
    notification_type   = "ACTUAL"
    subscriber_email_addresses = [
      var.mail_alert,
    ]
    subscriber_sns_topic_arns = [
      module.sns_budgets.topic_arn,
    ]
    threshold      = 30
    threshold_type = "PERCENTAGE"
  }
  notification {
    comparison_operator = "GREATER_THAN"
    notification_type   = "ACTUAL"
    subscriber_email_addresses = [
      var.mail_alert,
    ]
    subscriber_sns_topic_arns = [
      module.sns_budgets.topic_arn,
    ]
    threshold      = 60
    threshold_type = "PERCENTAGE"
  }
  notification {
    comparison_operator = "GREATER_THAN"
    notification_type   = "ACTUAL"
    subscriber_email_addresses = [
      var.mail_alert,
    ]
    subscriber_sns_topic_arns = [
      module.sns_budgets.topic_arn,
    ]
    threshold      = 100
    threshold_type = "PERCENTAGE"
  }

  notification {
    comparison_operator = "GREATER_THAN"
    notification_type   = "FORECASTED"
    subscriber_email_addresses = [
      var.mail_alert,
    ]
    subscriber_sns_topic_arns = [
      module.sns_budgets.topic_arn,
    ]
    threshold      = 150
    threshold_type = "PERCENTAGE"
  }
}

# OpenClaw 執事エージェントの Bedrock 利用分を監視する
# NOTE: Bedrock の Anthropic モデルは Marketplace 経由で請求されるため、
# 初回利用後に Cost Explorer で実際の Service 名を確認し、
# 異なる場合は values に追記すること（アカウント全体は "My Basic" がバックストップ）
resource "aws_budgets_budget" "openclaw_bedrock" {
  name              = "OpenClaw Bedrock"
  budget_type       = "COST"
  limit_amount      = "15.0"
  limit_unit        = "USD"
  time_period_start = "2026-08-01_00:00"
  time_unit         = "MONTHLY"

  cost_filter {
    name = "Service"
    values = [
      "Amazon Bedrock",
    ]
  }

  notification {
    comparison_operator = "GREATER_THAN"
    notification_type   = "ACTUAL"
    subscriber_email_addresses = [
      var.mail_alert,
    ]
    subscriber_sns_topic_arns = [
      module.sns_budgets.topic_arn,
    ]
    threshold      = 50
    threshold_type = "PERCENTAGE"
  }
  notification {
    comparison_operator = "GREATER_THAN"
    notification_type   = "ACTUAL"
    subscriber_email_addresses = [
      var.mail_alert,
    ]
    subscriber_sns_topic_arns = [
      module.sns_budgets.topic_arn,
    ]
    threshold      = 80
    threshold_type = "PERCENTAGE"
  }
  notification {
    comparison_operator = "GREATER_THAN"
    notification_type   = "ACTUAL"
    subscriber_email_addresses = [
      var.mail_alert,
    ]
    subscriber_sns_topic_arns = [
      module.sns_budgets.topic_arn,
    ]
    threshold      = 100
    threshold_type = "PERCENTAGE"
  }
  notification {
    comparison_operator = "GREATER_THAN"
    notification_type   = "FORECASTED"
    subscriber_email_addresses = [
      var.mail_alert,
    ]
    subscriber_sns_topic_arns = [
      module.sns_budgets.topic_arn,
    ]
    threshold      = 100
    threshold_type = "PERCENTAGE"
  }
}

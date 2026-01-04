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

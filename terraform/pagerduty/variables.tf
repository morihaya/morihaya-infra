variable "pagerduty_token" {
  description = "PagerDuty REST API token"
  type        = string
  sensitive   = true
}

variable "mail_own" {
  description = "Owner email address used for the PagerDuty user"
  type        = string
}

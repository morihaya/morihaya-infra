resource "pagerduty_user" "owner" {
  name  = "YUKIYA HAYASHI"
  email = var.mail_own
  role  = "owner"
}

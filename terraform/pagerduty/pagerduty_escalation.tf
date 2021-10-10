resource "pagerduty_escalation_policy" "default" {
  name      = "Default"
  num_loops = 0

  rule {
    escalation_delay_in_minutes = 30
    target {
      type = "user_reference"
      id   = pagerduty_user.owner.id
    }
  }
}

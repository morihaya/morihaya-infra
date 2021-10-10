resource "pagerduty_service" "default" {
  name                    = "morihaya"
  auto_resolve_timeout    = 14400
  acknowledgement_timeout = 600
  escalation_policy       = pagerduty_escalation_policy.default.id
  alert_creation          = "create_alerts_and_incidents"
  description             = <<-EOT
        Managed by Terraform.
        Your first service - describe what this service is monitoring and any information that will help responders. 
        For example: What is the SLA of this service? Where are the runbooks for this service stored? What tier level is this service?
        EOT
}

# Vendor Integrations
#  See: https://developer.pagerduty.com/api-reference/reference/REST/openapiv3.json/paths/~1vendors/get

## NewRelic
data "pagerduty_vendor" "newrelic" {
  name = "New Relic"
}

resource "pagerduty_service_integration" "newrelic" {
  name    = "New Relic"
  vendor  = data.pagerduty_vendor.newrelic.id
  service = pagerduty_service.default.id
}

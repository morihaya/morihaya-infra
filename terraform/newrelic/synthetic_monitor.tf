resource "newrelic_synthetics_monitor" "main" {
  for_each = {
    # key(FQDN to check site) = value(Validation string)
    "blog.morihaya.tech" = "morihaya"
    "github.com"         = "GitHub, Inc."
    "mail.google.com"    = "gmail"
    "example.com"        = "Example Domain"
  }
  name      = each.key
  type      = "SIMPLE"
  frequency = 15
  status    = "ENABLED"
  locations = ["AWS_AP_NORTHEAST_1"]

  uri               = "https://${each.key}" # Required for type "SIMPLE" and "BROWSER"
  validation_string = each.value            # Optional for type "SIMPLE" and "BROWSER"
  verify_ssl        = true                  # Optional for type "SIMPLE" and "BROWSER"
}

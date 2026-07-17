variable "newrelic_accountid" {
  description = "New Relic account ID"
  type        = string
}

variable "newrelic_key" {
  description = "New Relic user API key"
  type        = string
  sensitive   = true
}

provider "newrelic" {
  account_id = var.newrelic_accountid
  api_key    = var.newrelic_key
  region     = "US" # US or EU (defaults to US)
}

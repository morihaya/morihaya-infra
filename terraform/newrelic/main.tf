terraform {
  # Require the latest the New Relic provider
  required_providers {
    newrelic = {
      source = "newrelic/newrelic"
    }
  }
  backend "remote" {
    organization = "morihaya"

    workspaces {
      name = "morihaya-infra-newrelic"
    }
  }
}

variable "newrelic_accountid" {
  type = string  
}

variable "newrelic_key" {
  type = string  
}

provider "newrelic" {
  account_id = var.newrelic_accountid # Your New Relic account ID
  api_key    = var.newrelic_key       # Your New Relic user key
  region     = "US"                   # US or EU (defaults to US)
}

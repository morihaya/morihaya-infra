terraform {
  required_version = ">= 1.5.0"

  cloud {
    organization = "morihaya"

    workspaces {
      name = "morihaya-infra-newrelic"
    }
  }

  required_providers {
    newrelic = {
      source  = "newrelic/newrelic"
      version = "~> 3.76"
    }
  }
}

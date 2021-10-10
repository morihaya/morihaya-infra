terraform {
  backend "remote" {
    organization = "morihaya"

    workspaces {
      name = "morihaya-infra-pagerduty"
    }
  }
  required_providers {
    pagerduty = {
      source = "pagerduty/pagerduty"
    }
  }
}

provider "pagerduty" {
  token = var.pagerduty_token
}

variable "pagerduty_token" {
  type = string
}

variable "mail_own" {
  type = string
}

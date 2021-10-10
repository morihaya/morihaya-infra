terraform {
  backend "remote" {
    organization = "morihaya"

    workspaces {
      name = "morihaya-infra-tailscale"
    }
  }
  required_providers {
    tailscale = {
      source = "davidsbond/tailscale"
    }
  }
}

provider "tailscale" {
  api_key = var.tailscale_api_key
  tailnet = var.tailscale_tailnet
}
variable "tailscale_api_key" {
  type = string
}

variable "tailscale_tailnet" {
  type = string
}

variable "mail_own" {
  type = string
}

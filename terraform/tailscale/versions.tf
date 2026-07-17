terraform {
  required_version = ">= 1.5.0"

  cloud {
    organization = "morihaya"

    workspaces {
      name = "morihaya-infra-tailscale"
    }
  }

  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.21"
    }
  }
}

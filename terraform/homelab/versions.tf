terraform {
  required_version = ">= 1.5.0"

  cloud {
    organization = "morihaya"

    workspaces {
      name = "morihaya-infra-homelab"
    }
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111.0"
    }
  }
}

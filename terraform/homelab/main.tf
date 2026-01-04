terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.91.0"
    }
  }
}

# Provider configuration
# Authentication is handled via environment variables in HCP Terraform:
# - PROXMOX_VE_ENDPOINT
# - PROXMOX_VE_API_TOKEN
# - PROXMOX_VE_INSECURE
provider "proxmox" {
  # SSH configuration for operations requiring node access
  ssh {
    agent    = true
    username = var.proxmox_ssh_username
  }
}

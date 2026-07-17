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

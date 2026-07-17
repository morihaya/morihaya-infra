# =============================================================================
# Variables provided by HCP Terraform workspace settings
# (consumed by the provider via environment variables, not referenced directly)
# =============================================================================
# tflint-ignore: terraform_unused_declarations
variable "PROXMOX_VE_API_TOKEN" {
  description = "Proxmox VE API token (also consumed by the provider via environment variable)"
  type        = string
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "PROXMOX_VE_ENDPOINT" {
  description = "Proxmox VE API endpoint URL"
  type        = string
}

# tflint-ignore: terraform_unused_declarations
variable "PROXMOX_VE_INSECURE" {
  description = "Skip TLS verification when talking to the Proxmox VE API"
  type        = bool
  default     = true
}

# =============================================================================
# Proxmox Configuration Variables
# =============================================================================
variable "proxmox_node_name" {
  description = "Name of the Proxmox node"
  type        = string
  default     = "pve"
}

variable "proxmox_ssh_username" {
  description = "SSH username for Proxmox node (required for some operations)"
  type        = string
  default     = "root"
}

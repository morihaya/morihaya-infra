# =============================================================================
# Proxmox Configuration Variables in HCP Terraform
# =============================================================================
variable "PROXMOX_VE_API_TOKEN" {
  type = string
}
variable "PROXMOX_VE_ENDPOINT" {
  type = string
}
variable "PROXMOX_VE_INSECURE" {
  type    = bool
  default = true
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

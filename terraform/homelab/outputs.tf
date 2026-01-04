# =============================================================================
# Output Values
# =============================================================================

output "lxc_100_vm_id" {
  description = "VM ID of LXC Container 1"
  value       = proxmox_virtual_environment_container.lxc_100.vm_id
}

output "lxc_100_ipv4" {
  description = "IPv4 address of LXC Container 1"
  value       = proxmox_virtual_environment_container.lxc_100.ipv4
}

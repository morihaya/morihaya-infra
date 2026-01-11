# =============================================================================
# Output Values
# =============================================================================
## LXC Container 100
output "lxc_100_vm_id" {
  description = "VM ID of LXC Container 1"
  value       = proxmox_virtual_environment_container.lxc_100.vm_id
}

output "lxc_100_ipv4" {
  description = "IPv4 address of LXC Container 1"
  value       = proxmox_virtual_environment_container.lxc_100.ipv4
}
## LXC Container 101
output "lxc_101_vm_id" {
  description = "VM ID of LXC Container 2"
  value       = proxmox_virtual_environment_container.lxc_101.vm_id
}
output "lxc_101_ipv4" {
  description = "IPv4 address of LXC Container 2"
  value       = proxmox_virtual_environment_container.lxc_101.ipv4
}
## LXC Container 102
output "lxc_102_vm_id" {
  description = "VM ID of LXC Container 3"
  value       = proxmox_virtual_environment_container.lxc_102.vm_id
}
output "lxc_102_ipv4" {
  description = "IPv4 address of LXC Container 3"
  value       = proxmox_virtual_environment_container.lxc_102.ipv4
}
## VM Container 103
output "vm_103_vm_id" {
  description = "VM ID of traefik VM"
  value       = proxmox_virtual_environment_vm.vm_103.vm_id
}
output "vm_103_ipv4" {
  description = "IPv4 address of traefik VM"
  value       = proxmox_virtual_environment_vm.vm_103.ipv4_addresses
}
## LXC Container 104
output "lxc_104_vm_id" {
  description = "VM ID of Stalwart Mail Server"
  value       = proxmox_virtual_environment_container.lxc_104.vm_id
}
output "lxc_104_ipv4" {
  description = "IPv4 address of Stalwart Mail Server"
  value       = proxmox_virtual_environment_container.lxc_104.ipv4
}

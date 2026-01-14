# =============================================================================
# LXC Container 102 - Traefik
# =============================================================================
resource "proxmox_virtual_environment_container" "lxc_102" {
  node_name   = var.proxmox_node_name
  vm_id       = 102
  description = "LXC Container 102 - Managed by Terraform"

  unprivileged = true
  started      = true

  features {
    nesting = true
  }

  console {
    enabled   = true
    tty_count = 2
    type      = "tty"
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 512
    swap      = 512
  }

  disk {
    datastore_id = "local-lvm"
    size         = 8
  }

  network_interface {
    name     = "eth0"
    bridge   = "vmbr0"
    firewall = true
  }

  initialization {
    hostname = "traefik"

    ip_config {
      ipv4 {
        address = "192.168.1.6/24"
        gateway = "192.168.1.1"
      }
    }
  }

  operating_system {
    template_file_id = ""
    type             = "alpine"
  }

  lifecycle {
    ignore_changes = [
      initialization,
      operating_system,
    ]
  }
}


## Output Values
output "lxc_102_vm_id" {
  description = "VM ID of LXC Container 3"
  value       = proxmox_virtual_environment_container.lxc_102.vm_id
}
output "lxc_102_ipv4" {
  description = "IPv4 address of LXC Container 3"
  value       = proxmox_virtual_environment_container.lxc_102.ipv4
}

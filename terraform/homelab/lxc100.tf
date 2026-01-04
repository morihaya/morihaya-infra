# =============================================================================
# LXC Container 1
# =============================================================================
# Import: terraform import proxmox_virtual_environment_container.lxc_1 pve/100

import {
  to = proxmox_virtual_environment_container.lxc_100
  id = "pve/100"
}

resource "proxmox_virtual_environment_container" "lxc_100" {
  node_name   = var.proxmox_node_name
  vm_id       = 100
  description = "LXC Container 1 - Managed by Terraform"

  unprivileged = true
  started      = true

  features {
    nesting = true
  }

  console {
    enabled = true
    tty_count = 2
    type = "tty"
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
    name   = "eth0"
    bridge = "vmbr0"
    firewall = true
  }

  initialization {
    hostname = "dns01"

    ip_config {
      ipv4 {
        address = "192.168.1.4/24"
        gateway = "192.168.1.1"
      }
    }
  }

  operating_system {
    template_file_id = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
    type             = "ubuntu"
  }

  lifecycle {
    ignore_changes = [
      initialization,
      operating_system,
    ]
  }
}

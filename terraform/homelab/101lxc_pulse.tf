# =============================================================================
# LXC Container 101 - Pulse
# =============================================================================
resource "proxmox_virtual_environment_container" "lxc_101" {
  node_name   = var.proxmox_node_name
  vm_id       = 101
  description = "LXC Container 101 - Managed by Terraform"

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
    cores = 2
  }

  memory {
    dedicated = 1024
    swap      = 256
  }

  disk {
    datastore_id = "local-lvm"
    size         = 4
  }

  network_interface {
    name     = "eth0"
    bridge   = "vmbr0"
    firewall = true
  }

  initialization {
    hostname = "pulse"

    ip_config {
      ipv4 {
        address = "192.168.1.5/24"
        gateway = "192.168.1.1"
      }
    }
  }

  operating_system {
    template_file_id = ""
    type             = "debian"
  }

  startup {
    down_delay = -1
    order      = 99
    up_delay   = -1
  }

  lifecycle {
    ignore_changes = [
      initialization,
      operating_system,
    ]
  }
}

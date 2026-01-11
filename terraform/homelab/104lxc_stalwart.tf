# =============================================================================
# LXC Container 104 - Stalwart Mail Server
# =============================================================================
resource "proxmox_virtual_environment_container" "lxc_104" {
  node_name   = var.proxmox_node_name
  vm_id       = 104
  description = "Stalwart Mail Server - Managed by Terraform"

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
    dedicated = 2048
    swap      = 512
  }

  disk {
    datastore_id = "local-lvm"
    size         = 20
  }

  network_interface {
    name     = "eth0"
    bridge   = "vmbr0"
    firewall = true
  }

  initialization {
    hostname = "stalwart"

    ip_config {
      ipv4 {
        address = "192.168.1.8/24"
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

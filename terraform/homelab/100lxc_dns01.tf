# =============================================================================
# LXC Container 100 - DNS01
# =============================================================================
resource "proxmox_virtual_environment_container" "lxc_100" {
  node_name   = var.proxmox_node_name
  vm_id       = 100
  description = "LXC Container 1 - Managed by Terraform"

  unprivileged = true
  started      = true
  # DNS と DHCP を兼ねる最重要コンテナのため、明示的に自動起動を宣言する
  start_on_boot = true

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
    datastore_id = var.guest_datastore_id
    size         = 8
  }

  network_interface {
    name     = "eth0"
    bridge   = "vmbr0"
    firewall = true
  }

  initialization {
    hostname = "dns01"

    ip_config {
      ipv4 {
        # 実機は /32 (`ip=192.168.1.4/32`)。gw 経由のホストルートで動作しては
        # いるが他のコンテナは /24 であり、意図しない設定の可能性が高い。
        # ignore_changes により Terraform からは矯正されないため、直す場合は
        # Proxmox 側で /24 に変更すること。
        address = "192.168.1.4/32"
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
      node_name, # HA によるフェイルオーバー先を Terraform で巻き戻さない
    ]
  }
}


## Output Values
output "lxc_100_vm_id" {
  description = "VM ID of LXC Container 1"
  value       = proxmox_virtual_environment_container.lxc_100.vm_id
}

output "lxc_100_ipv4" {
  description = "IPv4 address of LXC Container 1"
  value       = proxmox_virtual_environment_container.lxc_100.ipv4
}

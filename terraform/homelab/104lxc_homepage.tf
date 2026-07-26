# =============================================================================
# LXC Container 104 - Homepage (dashboard)
#
# community-scripts/ProxmoxVE の Homepage LXC スクリプトで手動作成されたものを
# 後から Terraform 管理下に取り込んだコンテナ。
# 初回 apply で description が community-script のバナー HTML から下記の文言へ
# 書き換わるが、これは表示上のコメントのみで動作に影響はない。
# =============================================================================
resource "proxmox_virtual_environment_container" "lxc_104" {
  node_name   = var.proxmox_node_name
  vm_id       = 104
  description = "LXC Container 104 - Homepage dashboard - Managed by Terraform"

  unprivileged  = true
  started       = true
  start_on_boot = true

  tags = ["community-script", "dashboard"]

  features {
    nesting = true
    keyctl  = true
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 512
    swap      = 512
  }

  disk {
    datastore_id = var.guest_datastore_id
    size         = 6
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  initialization {
    hostname = "homepage"

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

  lifecycle {
    ignore_changes = [
      initialization,
      operating_system,
      node_name, # HA によるフェイルオーバー先を Terraform で巻き戻さない
    ]
  }
}

## Output Values
output "lxc_104_vm_id" {
  description = "VM ID of the homepage LXC container"
  value       = proxmox_virtual_environment_container.lxc_104.vm_id
}

output "lxc_104_ipv4" {
  description = "IPv4 address of the homepage LXC container"
  value       = proxmox_virtual_environment_container.lxc_104.ipv4
}

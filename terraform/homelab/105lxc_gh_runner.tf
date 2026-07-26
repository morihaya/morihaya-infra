# =============================================================================
# LXC Container 105 - GitHub Actions self-hosted runner
#
# 以前の removed.tf は「105 は Proxmox 上で削除済み」としていたが、実際には
# pve3 上で稼働中であり、かつクラスタ内で唯一 HA 登録されているゲストだった。
# removed ブロックの apply は実行されておらず state にも残っていたため、
# ファイルごと実態に合わせて書き直す (import 不要)。
#
# node_name は HA によるフェイルオーバーで変化するため ignore_changes に入れる。
# これを入れないと HA が移動させた直後に Terraform が元ノードへ戻そうとする。
# =============================================================================
resource "proxmox_virtual_environment_container" "lxc_105" {
  node_name   = "pve3"
  vm_id       = 105
  description = "GitHub Actions Self-hosted Runner - Managed by Terraform"

  unprivileged  = true
  started       = true
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
    cores = 2
    units = 1024
  }

  memory {
    dedicated = 2048
    swap      = 512
  }

  disk {
    datastore_id = var.guest_datastore_id
    size         = 20
  }

  network_interface {
    name     = "eth0"
    bridge   = "vmbr0"
    firewall = true
  }

  initialization {
    hostname = "gh-runner"

    ip_config {
      ipv4 {
        address = "192.168.1.9/24"
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
      node_name, # HA によるフェイルオーバー先を Terraform で巻き戻さない
    ]
  }
}

## Output Values
output "lxc_105_vm_id" {
  description = "VM ID of the GitHub Actions runner LXC container"
  value       = proxmox_virtual_environment_container.lxc_105.vm_id
}

output "lxc_105_ipv4" {
  description = "IPv4 address of the GitHub Actions runner LXC container"
  value       = proxmox_virtual_environment_container.lxc_105.ipv4
}

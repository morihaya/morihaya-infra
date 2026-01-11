# =============================================================================
# Virtual Machine 103 - HCP Terraform Agent
# =============================================================================

import {
  to = proxmox_virtual_environment_vm.vm_103
  id = "pve/103"
}

resource "proxmox_virtual_environment_vm" "vm_103" {
  node_name   = var.proxmox_node_name
  vm_id       = 103
  name        = "hcp-terraform-agent"
  description = "HCP Terraform Agent - Managed by Terraform"

  started = true

  # CPU設定
  cpu {
    cores   = 1
    sockets = 1
    type    = "x86-64-v2-AES"
    numa    = false
  }

  # メモリ設定
  memory {
    dedicated = 2304
  }

  # ブートディスク (scsi0)
  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 32
    iothread     = true
  }

  # CD-ROM (ide2) - Ubuntu ISOがマウントされている
  cdrom {
    file_id   = "local:iso/ubuntu-24.04.3-live-server-amd64.iso"
    interface = "ide2"
  }

  # ネットワーク設定
  network_device {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = true
  }

  # BIOS設定
  bios = "seabios"

  # SCSI Controller
  scsi_hardware = "virtio-scsi-single"

  # OS Type
  operating_system {
    type = "l26"
  }

  # Boot順序
  boot_order = ["scsi0", "ide2", "net0"]

  # QEMU Guest Agent (現在無効)
  #agent {
  #}

  # SMBIOS UUID
  machine = "pc"

  lifecycle {
    ignore_changes = [
      # インポート後に変更を無視する項目
      cdrom,
      disk,
      network_device,
    ]
  }
}

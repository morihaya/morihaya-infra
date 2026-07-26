# =============================================================================
# Virtual Machine 103 - HCP Terraform Agent
# =============================================================================

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
    datastore_id = var.guest_datastore_id
    interface    = "scsi0"
    size         = 32
    iothread     = true
  }

  # CD-ROM (ide2) はインストール完了後も刺さったままだったが、その ISO は
  # pve の local ストレージにしか存在せず、このVMのマイグレーションを
  # 妨げていた。ZFS 移行の事前準備 (docs/zfs-ha-migration.md の Phase 0-3) で
  # `qm set 103 --delete ide2` により取り外したため、定義ごと削除する。

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

  # Boot順序 (ide2 取り外しに伴い scsi0 のみ)
  boot_order = ["scsi0"]

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


## Output Values
output "vm_103_vm_id" {
  description = "VM ID of traefik VM"
  value       = proxmox_virtual_environment_vm.vm_103.vm_id
}
output "vm_103_ipv4" {
  description = "IPv4 address of traefik VM"
  value       = proxmox_virtual_environment_vm.vm_103.ipv4_addresses
}

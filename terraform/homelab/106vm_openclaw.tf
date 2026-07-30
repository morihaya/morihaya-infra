# =============================================================================
# Virtual Machine 106 - OpenClaw (自宅 Slack 常駐の執事エージェント)
#
# 構築計画の全体は リポジトリ直下の docs/openclaw-butler-handover.md を参照。
#
# 【LXC ではなく VM にする理由】
# OpenClaw はエージェント自身がシェルを実行できる。プロンプトインジェクション
# で意図しないコマンドを走らされた場合の影響を、カーネルを共有しない VM の
# 境界で止めたいため。他のゲストが LXC なのに対しここだけ VM にしている。
#
# 【スペックの根拠】
# 公式の推奨は 4vCPU/8GB だが、それはブラウザ自動化 (Chromium 同梱) を使う
# 場合の数字。推論はすべて Amazon Bedrock 側で行うためローカルの計算資源は
# ほぼ不要で、ブラウザ自動化なしなら 2vCPU/4GB で足りる。
# クラスタのメモリにも余裕が無く、8GB を積むと ha.tf のフェイルオーバー
# 収容計算が破綻する (pve3 は 8GB しか無い)。
#
# 【既存ゲストとの違い】
# 100-105 は手動作成したものを import した経緯があり initialization と
# operating_system が ignore_changes に入っている。この 106 は Terraform で
# 新規作成するため ignore_changes に入れない (cloud-init の設定をコードで
# 管理し続ける)。
# =============================================================================

# -----------------------------------------------------------------------------
# Debian 12 (bookworm) の cloud image
# ゲストディスクと違いノードローカルの `local` に置く。レプリケーション対象では
# ないが、VM 作成時に import 元として一度読むだけなので複製は不要。
# -----------------------------------------------------------------------------
resource "proxmox_download_file" "debian12_genericcloud" {
  node_name    = "pve3"
  datastore_id = "local"
  content_type = "iso"

  # qcow2 のままだと content_type = "iso" が受け付けないため .img で保存する
  file_name = "debian-12-genericcloud-amd64.img"
  url       = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"

  # latest は中身が更新され続けるためチェックサム検証は行わない。
  # 検証したい場合は同ディレクトリの SHA512SUMS から値を取って
  # checksum / checksum_algorithm を指定する。
  overwrite = false
}

resource "proxmox_virtual_environment_vm" "vm_106" {
  node_name   = "pve3"
  vm_id       = 106
  name        = "openclaw"
  description = "OpenClaw butler agent (Slack + Amazon Bedrock) - Managed by Terraform"

  started         = true
  on_boot         = true
  stop_on_destroy = true

  cpu {
    cores   = 2
    sockets = 1
    type    = "x86-64-v2-AES"
    numa    = false
  }

  memory {
    dedicated = 4096
  }

  # ブートディスク。cloud image を import して 40GB へ拡張する。
  # OpenClaw のイメージは 2-4GB 程度だが、会話履歴とメモリが育つため余裕を持たせる。
  disk {
    datastore_id = var.guest_datastore_id
    import_from  = proxmox_download_file.debian12_genericcloud.id
    interface    = "scsi0"
    size         = 40
    iothread     = true
  }

  # cloud-init
  initialization {
    datastore_id = var.guest_datastore_id

    ip_config {
      ipv4 {
        address = "192.168.1.12/24"
        gateway = "192.168.1.1"
      }
    }

    user_account {
      username = "morihaya"
      # ansible 側と鍵の実体を二重管理しないよう、common ロールの
      # authorized_keys をそのまま読む。先頭のコメント行は除外する。
      keys = [
        for line in split("\n", trimspace(file("${path.module}/../../ansible/roles/common/keys/authorized_keys.morihaya"))) :
        trimspace(line) if length(trimspace(line)) > 0 && !startswith(trimspace(line), "#")
      ]
    }
  }

  network_device {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = true
  }

  bios          = "seabios"
  scsi_hardware = "virtio-scsi-single"
  machine       = "pc"
  boot_order    = ["scsi0"]

  operating_system {
    type = "l26"
  }

  # QEMU Guest Agent は Debian の genericcloud イメージに同梱されていないため
  # 有効化しない (有効にすると provider が起動時にエージェント応答を待ち続ける)。
  # 導入後に ansible で qemu-guest-agent を入れてから有効化する。

  startup {
    down_delay = -1
    order      = 99
    up_delay   = -1
  }

  lifecycle {
    ignore_changes = [
      node_name, # HA によるフェイルオーバー先を Terraform で巻き戻さない
    ]
  }
}

## Output Values
output "vm_106_vm_id" {
  description = "VM ID of the OpenClaw butler agent VM"
  value       = proxmox_virtual_environment_vm.vm_106.vm_id
}

output "vm_106_ipv4" {
  description = "Static IPv4 address of the OpenClaw butler agent VM (cloud-init assigned)"
  value       = "192.168.1.12"
}

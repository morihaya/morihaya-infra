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
# cloud image を置くための import 用ストレージ
#
# 【なぜ local を使わないか】
# 当初は `local` に content_type = "iso" でダウンロードしたが、VM 作成が
# 次のエラーで失敗した。
#
#   scsi0: local:iso/debian-12-genericcloud-amd64.img has wrong type 'iso'
#   - needs to be 'images' or 'import'
#
# ディスクの import 元は `images` か `import` タイプのストレージに無ければ
# ならない (PVE 8.4 以降で追加された `import` コンテンツタイプ)。`local` に
# `import` を足すこともできるが、`local` はクラスタ全ノードの ISO・バックアップ・
# コンテナテンプレートを抱えているため Terraform 管理下に import したくない。
# 影響範囲を切り離すため専用ストレージを新設する。
# -----------------------------------------------------------------------------
resource "proxmox_storage_directory" "image_import" {
  id      = "image-import"
  path    = "/var/lib/pve-image-import"
  content = ["import"]

  # cloud image を読むのは VM 作成時の pve3 だけなので他ノードには広げない
  nodes = ["pve3"]

  # ディレクトリと配下の import/ を PVE 側に作らせる
  create_base_path = true
  create_subdirs   = true
}

# -----------------------------------------------------------------------------
# 旧 cloud image (local:iso/debian-12-genericcloud-amd64.img) を
# destroy せずに state から外す
#
# `local` から `image-import` へ移す変更は Terraform 上は「置き換え」になるが、
# その destroy が次のエラーで失敗し apply が止まった。
#
#   Error: Error deleting datastore file
#   Could not delete datastore file 'local:iso/debian-12-genericcloud-amd64.img'
#   ... received an HTTP 400 response - Reason: Bad Request
#
# PVE は content_type ごとにファイル名と拡張子を検証しており、`iso` 配下の
# `.img` は削除 API でも弾かれる (bpg プロバイダ側でも既知: ファイルが存在
# しない場合の destroy 失敗を含む)。API 経由では消せないため、Terraform には
# 「忘れさせる」だけにしてファイルの後片付けはノード上で手動で行う。
#
# この removed ブロックは state から外れたことを確認したら削除してよい。
# -----------------------------------------------------------------------------
removed {
  from = proxmox_download_file.debian12_genericcloud

  lifecycle {
    destroy = false
  }
}

# -----------------------------------------------------------------------------
# Debian 12 (bookworm) の cloud image
# ゲストディスク (local-zfs) と違いレプリケーション対象ではないが、VM 作成時に
# import 元として一度読むだけなので複製は不要。
#
# 上記の removed ブロックと同時に成立させるためリソース名を変えている
# (同じアドレスのままでは「置き換え = destroy が走る」ため)。
# -----------------------------------------------------------------------------
resource "proxmox_download_file" "debian12_import" {
  node_name    = "pve3"
  datastore_id = proxmox_storage_directory.image_import.id
  content_type = "import"

  # import タイプは qcow2 をそのまま扱えるため拡張子の付け替えは不要
  file_name = "debian-12-genericcloud-amd64.qcow2"
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
    import_from  = proxmox_download_file.debian12_import.id
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

  # シリアルコンソール。Debian の cloud image には必須。
  #
  # 【無いとどうなるか】
  # イメージの GRUB 設定は次のようになっており、最後の console= が
  # /dev/console になるため ttyS0 が存在しないと PID 1 の書き込みが失敗する。
  #
  #   GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200 earlyprintk=ttyS0,115200 consoleblank=0"
  #
  # 実際にこれを省いた初回起動は、カーネルは上がるものの systemd が即死して
  # 次のパニックで止まった (ネットワークも 1 パケットも出ないまま)。
  #
  #   Kernel panic - not syncing: Attempted to kill init! exitcode=0x00000200
  #
  # Proxmox の VM は既定でシリアルポートを持たないため、cloud image を使う
  # ゲストでは明示的に足す必要がある。VGA はそのまま残すので Web コンソールも
  # 従来どおり使える。
  serial_device {
    device = "socket"
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

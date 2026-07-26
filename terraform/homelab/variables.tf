# =============================================================================
# Proxmox provider の認証情報 (PROXMOX_VE_ENDPOINT / PROXMOX_VE_API_TOKEN /
# PROXMOX_VE_INSECURE) はここで宣言しない。
#
# provider は OS の環境変数として読むため、HCP 側では Homelab variable set に
# Environment カテゴリで登録する。Terraform カテゴリにすると、宣言していない
# 変数に値が渡ることになり plan のたびに次の警告が出る。
#
#   Warning: Value for undeclared variable
#
# 宣言を足して黙らせることもできるが、provider が使わない変数の
# tflint-ignore 付きダミー宣言が増えるだけで、実態も分かりにくくなる。
# =============================================================================
# =============================================================================
# Proxmox Configuration Variables
# =============================================================================
variable "proxmox_node_name" {
  description = "Name of the Proxmox node"
  type        = string
  default     = "pve"
}

variable "proxmox_ssh_username" {
  description = "SSH username for Proxmox node (required for some operations)"
  type        = string
  default     = "root"
}

variable "proxmox_cluster_nodes" {
  description = "All nodes in the `morihaya` Proxmox cluster"
  type        = list(string)
  default     = ["pve", "pve2", "pve3"]
}

# =============================================================================
# High Availability
#
# HA でゲストを別ノードへフェイルオーバーさせるには、フェイルオーバー先に
# ディスクの複製が存在している必要がある。本クラスタには共有ストレージが無く
# 各ノードのディスクは 1 本ずつなので、ZFS + ストレージレプリケーション
# (pvesr) で複製を作る方式を採る。
#
# ZFS プールの作成自体は破壊的作業のため Terraform では行わない。
# 手順は docs/zfs-ha-migration.md を参照し、完了してから enable_ha を true に
# すること。ZFS 化前に true にすると、レプリカを持たないノードへ HA が
# ゲストを起動しようとして失敗する。
# =============================================================================
variable "enable_ha" {
  description = "Enable ZFS storage registration, storage replication and HA resources. The local-lvm to ZFS migration completed on 2026-07-26, so this is now on by default."
  type        = bool
  default     = true
}

variable "guest_datastore_id" {
  description = "Datastore holding guest root disks. Storage replication only works on ZFS. Migrated from local-lvm on 2026-07-26; local-lvm no longer exists on any node."
  type        = string
  default     = "local-zfs"
}

variable "zfs_storage_id" {
  description = "Proxmox storage id to register for the ZFS pool"
  type        = string
  default     = "local-zfs"
}

variable "zfs_pool_name" {
  description = "Name of the ZFS pool created on each node during the migration"
  type        = string
  default     = "rpool_data"
}

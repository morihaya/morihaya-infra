# =============================================================================
# Variables provided by HCP Terraform workspace settings
# (consumed by the provider via environment variables, not referenced directly)
# =============================================================================
# tflint-ignore: terraform_unused_declarations
variable "PROXMOX_VE_API_TOKEN" {
  description = "Proxmox VE API token (also consumed by the provider via environment variable)"
  type        = string
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "PROXMOX_VE_ENDPOINT" {
  description = "Proxmox VE API endpoint URL"
  type        = string
}

# tflint-ignore: terraform_unused_declarations
variable "PROXMOX_VE_INSECURE" {
  description = "Skip TLS verification when talking to the Proxmox VE API"
  type        = bool
  default     = true
}

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
  description = "Enable ZFS storage registration, storage replication and HA resources. Only set to true AFTER the local-lvm to ZFS migration described in docs/zfs-ha-migration.md is complete on every node."
  type        = bool
  default     = false
}

variable "guest_datastore_id" {
  description = "Datastore holding guest root disks. Switch to the ZFS storage id once the migration is complete; storage replication only works on ZFS."
  type        = string
  default     = "local-lvm"
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

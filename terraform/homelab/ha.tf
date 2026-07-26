# =============================================================================
# High Availability (ZFS storage replication + HA resources)
#
# 【前提】このファイルのリソースは var.enable_ha = false の間は一切作られない。
# ZFS 移行 (docs/zfs-ha-migration.md) が全ノードで完了してから有効化すること。
#
# 【設計方針】
# 本クラスタには共有ストレージが無いため、HA は「ZFS レプリケーションで複製を
# 置いたノードにだけフェイルオーバーさせる」構成にする。
#
#   - ゲストごとにレプリケーション先 (standby) を 1 ノードだけ決める
#     3 ノード全てに複製すると 1GbE と非力な pve2 には負荷が重いため
#   - node-affinity ルールを strict = true にして、複製を持たない
#     ノードへ HA が起動を試みるのを禁止する
#     (strict を外すと複製の無いノードで起動に失敗し、サービスが停止したままになる)
#
# 【フェイルオーバー時のメモリ収容】
#   pve 障害時  -> pve3 が 100/101/102 (計 2.0GB) を引き取る。pve3 は自分の
#                  105 (2GB) と合わせて 4.0GB / 8GB で収まる。
#                  pve2 が 104 (4GB) を引き取り 4.0GB / 7.5GB。
#   pve3 障害時 -> pve2 が 105 (2GB) を引き取る。
#
# 【データ欠損】レプリケーションは非同期のため、障害時は最大で schedule
# 間隔ぶんの書き込みが失われる。DNS/DHCP と Traefik は 5 分、
# それ以外は 15 分間隔とする。
#
# 【重要 / bpg プロバイダの既知の制約】
# プロバイダはコンテナを state に記録された node_name のノードにだけ問い合わせる。
# HA がフェイルオーバーさせると state のノードには居なくなるため、次の plan で
# 「削除された → 作り直す」と判定される (プロバイダ README の Known Issues
# "HA VMs / containers" 参照)。`ignore_changes = [node_name]` は config と state
# の差分を無視するだけで、この読み取り時の 404 は防げない。
# なお VMID はクラスタ全体で一意なので、その apply は「既に存在する」エラーで
# 失敗するだけでコンテナが壊れることはない。復旧手順は
# docs/zfs-ha-migration.md の「フェイルオーバー後の state 復旧」を参照。
# =============================================================================

locals {
  # vmid => フェイルオーバー設定
  ha_guests = {
    100 = {
      name     = "dns01"
      primary  = "pve"
      standby  = "pve3"
      schedule = "*/5"
    }
    101 = {
      name     = "pulse"
      primary  = "pve"
      standby  = "pve3"
      schedule = "*/15"
    }
    102 = {
      name     = "traefik"
      primary  = "pve"
      standby  = "pve3"
      schedule = "*/5"
    }
    104 = {
      name     = "homepage"
      primary  = "pve"
      standby  = "pve2"
      schedule = "*/15"
    }
    105 = {
      name     = "gh-runner"
      primary  = "pve3"
      standby  = "pve2"
      schedule = "*/15"
    }
  }

  ha_guests_enabled = var.enable_ha ? local.ha_guests : {}
}

# -----------------------------------------------------------------------------
# ZFS プールを Proxmox のストレージとして登録する
# プール自体の作成 (zpool create) は破壊的なため手順書側で実施する。
# -----------------------------------------------------------------------------
resource "proxmox_storage_zfspool" "guest_storage" {
  count = var.enable_ha ? 1 : 0

  id             = var.zfs_storage_id
  zfs_pool       = var.zfs_pool_name
  nodes          = var.proxmox_cluster_nodes
  content        = ["images", "rootdir"]
  thin_provision = true
}

# -----------------------------------------------------------------------------
# ストレージレプリケーション (pvesr)
# -----------------------------------------------------------------------------
resource "proxmox_replication" "guest" {
  for_each = local.ha_guests_enabled

  id       = "${each.key}-0"
  type     = "local"
  target   = each.value.standby
  schedule = each.value.schedule
  comment  = "${each.value.name}: ${each.value.primary} -> ${each.value.standby} (managed by Terraform)"

  depends_on = [proxmox_storage_zfspool.guest_storage]
}

# -----------------------------------------------------------------------------
# HA リソース登録
# -----------------------------------------------------------------------------
resource "proxmox_haresource" "guest" {
  for_each = local.ha_guests_enabled

  resource_id = "ct:${each.key}"
  state       = "started"

  # 復旧したノードへ自動的に戻さない。戻す動作は 2 回目の短時間停止を生むため、
  # レプリケーションの追いつきを確認したうえで手動で戻す運用にする。
  failback = false

  max_restart  = 2
  max_relocate = 2

  comment = "${each.value.name} (managed by Terraform)"

  depends_on = [proxmox_replication.guest]
}

# -----------------------------------------------------------------------------
# node-affinity ルール (PVE 9 で HA groups から移行された新形式)
# 優先度の高いノードが primary、低いほうが standby。
# -----------------------------------------------------------------------------
resource "proxmox_harule" "node_affinity" {
  for_each = local.ha_guests_enabled

  rule      = "node-affinity-${each.value.name}"
  type      = "node-affinity"
  resources = ["ct:${each.key}"]

  # 複製を持つ 2 ノード以外では絶対に起動させない
  strict = true

  nodes = {
    (each.value.primary) = 2
    (each.value.standby) = 1
  }

  comment = "${each.value.name}: replica exists only on ${each.value.primary} and ${each.value.standby}"

  depends_on = [proxmox_haresource.guest]
}

## Output Values
output "ha_enabled" {
  description = "Whether HA resources and storage replication are managed by this configuration"
  value       = var.enable_ha
}

output "ha_failover_map" {
  description = "Failover target and replication interval for each HA-managed guest"
  value = {
    for id, g in local.ha_guests :
    g.name => "ct:${id} ${g.primary} -> ${g.standby} (every ${g.schedule})"
  }
}

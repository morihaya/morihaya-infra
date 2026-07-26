# =============================================================================
# ZFS 移行 (docs/zfs-ha-migration.md) の途中では、対象ノードが 1 台ずつ増えて
# いくため `local-zfs` ストレージを pvesm で手動登録した。実体が既にあるので
# 作成ではなく取り込む。
#
#   pvesm add zfspool local-zfs --pool rpool_data --content images,rootdir --nodes pve2
#
# apply 完了後、このファイルは削除してよい。
# =============================================================================
import {
  to = proxmox_storage_zfspool.guest_storage[0]
  id = var.zfs_storage_id
}

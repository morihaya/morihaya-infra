# =============================================================================
# LXC Container 105 (gh-runner) は Proxmox 上で削除済みのため管理対象から外す。
# destroy = false により state から forget するのみ(実リソース操作なし)。
# apply 完了後にこのファイルは削除してよい。
# =============================================================================
removed {
  from = proxmox_virtual_environment_container.lxc_105

  lifecycle {
    destroy = false
  }
}

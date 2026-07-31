# =============================================================================
# 既存ワークスペースの取り込み
#
# tfe_workspace の import ID は "<ORGANIZATION>/<WORKSPACE NAME>"。
#
# apply が完了したらこのファイルは役目を終えるので削除すること
# (前回の取り込み時も同様に imports.tf を削除している)。
# =============================================================================

import {
  to = tfe_workspace.this["minecraft-server-oci"]
  id = "morihaya/minecraft-server-oci"
}

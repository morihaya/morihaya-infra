# =============================================================================
# 既存ワークスペースの取り込み
#
# tfe_workspace の import ID は "<organization>/<workspace name>"。
# apply が完了したらこのファイルは削除してよい。
# =============================================================================
import {
  to = tfe_workspace.this["aws-common-r53"]
  id = "morihaya/morihaya-infra-aws-common-r53"
}

import {
  to = tfe_workspace.this["aws-root"]
  id = "morihaya/morihaya-infra-aws-root"
}

import {
  to = tfe_workspace.this["azure"]
  id = "morihaya/morihaya-infra-azure"
}

import {
  to = tfe_workspace.this["homelab"]
  id = "morihaya/morihaya-infra-homelab"
}

import {
  to = tfe_workspace.this["newrelic"]
  id = "morihaya/morihaya-infra-newrelic"
}

import {
  to = tfe_workspace.this["pagerduty"]
  id = "morihaya/morihaya-infra-pagerduty"
}

import {
  to = tfe_workspace.this["tailscale"]
  id = "morihaya/morihaya-infra-tailscale"
}

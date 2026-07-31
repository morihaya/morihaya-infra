# =============================================================================
# HCP Terraform workspaces in the morihaya organization
#
# ここは「HCP Terraform 自体を管理する」ルート。UI でしか見えない設定が
# 長期間放置されて実害が出たため IaC 化した (詳細は README.md)。
#
# 管理対象は本リポジトリのワークスペースに限らない。org 内のワークスペースは
# ここへ集約する。VCS のバックエンドとなるリポジトリはワークスペースごとに
# 異なるため vcs_identifier で個別に指定する。
#
# 【重要】この時点では実態をそのまま写し取ることだけを目的としている。
# 下表のとおり terraform_version / auto_apply / speculative / working_directory
# はワークスペースごとにバラバラだが、意図的に現状のまま記述して plan を
# no-op に保っている。統一は別 PR で行う。
#
# 【自分自身は管理しない】このルートを動かす morihaya-infra ワークスペースは
# 管理対象に含めない。自分が乗っている枝を切る事故を防ぐため。
# =============================================================================

data "tfe_github_app_installation" "this" {
  name = var.github_app_installation_name
}

data "tfe_agent_pool" "homelab" {
  name         = var.homelab_agent_pool_name
  organization = var.tfe_organization
}

data "tfe_project" "aws" {
  name         = "AWS"
  organization = var.tfe_organization
}

data "tfe_project" "azure" {
  name         = "Azure"
  organization = var.tfe_organization
}

data "tfe_project" "homelab" {
  name         = "HomeLab"
  organization = var.tfe_organization
}

data "tfe_project" "oci" {
  name         = "OCI"
  organization = var.tfe_organization
}

data "tfe_project" "default" {
  name         = "Default Project"
  organization = var.tfe_organization
}

locals {
  # 現状のワークスペース設定。値は 2026-07-26 時点の実態。
  workspaces = {
    aws-common-r53 = {
      name              = "morihaya-infra-aws-common-r53"
      description       = "共通系のr53を管理する。テスト用としても。"
      project_id        = data.tfe_project.aws.id
      working_directory = "terraform/aws/common-r53"
      trigger_patterns  = ["/terraform/aws/common-r53/*.tf"]
      terraform_version = "~>1.14.0"
      execution_mode    = "remote"
      # このワークスペースだけ auto_apply が有効。マージした時点で適用される。
      auto_apply             = true
      auto_apply_run_trigger = true
      speculative_enabled    = true
      vcs                    = true
      vcs_identifier         = var.vcs_repo_identifier
    }

    aws-root = {
      name        = "morihaya-infra-aws-root"
      description = "My personal AWS root"
      project_id  = data.tfe_project.aws.id
      # 末尾スラッシュ付き。他と不統一だが実態どおり。
      working_directory = "terraform/aws/root/"
      # 先頭 "./" 付き。他と不統一だが実態どおり。
      trigger_patterns       = ["./terraform/aws/root/*.tf"]
      terraform_version      = "~>1.14.0"
      execution_mode         = "remote"
      auto_apply             = false
      auto_apply_run_trigger = false
      # speculative 無効。PR 時に plan が走らない。
      speculative_enabled = false
      vcs                 = true
      vcs_identifier      = var.vcs_repo_identifier
    }

    azure = {
      name                   = "morihaya-infra-azure"
      description            = null
      project_id             = data.tfe_project.azure.id
      working_directory      = "/terraform/azure"
      trigger_patterns       = ["/terraform/azure/*.tf"]
      terraform_version      = "~>1.14.0"
      execution_mode         = "remote"
      auto_apply             = true
      auto_apply_run_trigger = true
      speculative_enabled    = true
      vcs                    = true
      vcs_identifier         = var.vcs_repo_identifier
    }

    homelab = {
      name              = "morihaya-infra-homelab"
      description       = null
      project_id        = data.tfe_project.homelab.id
      working_directory = "/terraform/homelab"
      trigger_patterns  = ["/terraform/homelab/*.tf"]
      terraform_version = "~>1.14.0"
      # Proxmox の API はインターネットから到達できないため agent 実行。
      # agent は VM 103 (pve 上) で動いている。
      execution_mode         = "agent"
      auto_apply             = false
      auto_apply_run_trigger = false
      speculative_enabled    = true
      vcs                    = true
      vcs_identifier         = var.vcs_repo_identifier
    }

    newrelic = {
      name              = "morihaya-infra-newrelic"
      description       = null
      project_id        = data.tfe_project.default.id
      working_directory = "/terraform/newrelic/"
      trigger_patterns  = ["/terraform/newrelic/*.tf"]
      # Terraform 1.0.8 のまま。要更新。
      terraform_version      = "1.0.8"
      execution_mode         = "remote"
      auto_apply             = false
      auto_apply_run_trigger = false
      speculative_enabled    = false
      vcs                    = true
      vcs_identifier         = var.vcs_repo_identifier
    }

    # 2026-07-26 に local から remote へ移行した。以前は HCP を state の保管場所
    # としてのみ使い plan/apply は手元で走らせていたが、久しぶりに触ると手順を
    # 思い出せない状態だったため、他のワークスペースと同じ VCS 駆動に揃えた。
    # 必要な変数 (pagerduty_token / mail_own) は PagerDuty variable set に登録済み。
    pagerduty = {
      name                   = "morihaya-infra-pagerduty"
      description            = null
      project_id             = data.tfe_project.default.id
      working_directory      = "terraform/pagerduty"
      trigger_patterns       = ["/terraform/pagerduty/*.tf"]
      terraform_version      = "~>1.14.0"
      execution_mode         = "remote"
      auto_apply             = false
      auto_apply_run_trigger = false
      speculative_enabled    = true
      vcs                    = true
      vcs_identifier         = var.vcs_repo_identifier
    }

    tailscale = {
      name                   = "morihaya-infra-tailscale"
      description            = "https://tailscale.com/"
      project_id             = data.tfe_project.default.id
      working_directory      = ""
      trigger_patterns       = []
      terraform_version      = "1.0.8"
      execution_mode         = "local"
      auto_apply             = false
      auto_apply_run_trigger = false
      speculative_enabled    = false
      vcs                    = false
      # VCS 連携が無いので参照されない。map の型を揃えるためだけに置いている。
      vcs_identifier = null
    }

    # 本リポジトリ外のワークスペース。OCI 上の Minecraft サーバの
    # セキュリティリストを管理する morihaya/hayashi-ke-minecraft-server が
    # バックエンド。2026-07-31 に取り込んだ。
    #
    # auto_apply が有効なのでマージすれば適用まで自動で進む。その代わり
    # apply が失敗しても PR 上に何も出ないため、リポジトリ側に
    # hcp-tf-comment.yml を置いて run へのリンクをコメントさせている。
    minecraft-server-oci = {
      name              = "minecraft-server-oci"
      description       = "GitHub Repo: https://github.com/morihaya/hayashi-ke-minecraft-server\n"
      project_id        = data.tfe_project.oci.id
      working_directory = "terraform"
      # trigger_patterns が空の場合、HCP は working_directory を
      # トリガとして扱う。実態どおり空のままにしている。
      trigger_patterns       = []
      terraform_version      = "1.12.2"
      execution_mode         = "remote"
      auto_apply             = true
      auto_apply_run_trigger = true
      speculative_enabled    = true
      vcs                    = true
      vcs_identifier         = "morihaya/hayashi-ke-minecraft-server"
    }
  }
}

resource "tfe_workspace" "this" {
  for_each = local.workspaces

  name         = each.value.name
  organization = var.tfe_organization
  project_id   = each.value.project_id
  description  = each.value.description

  working_directory = each.value.working_directory
  terraform_version = each.value.terraform_version

  execution_mode = each.value.execution_mode
  agent_pool_id  = each.value.execution_mode == "agent" ? data.tfe_agent_pool.homelab.id : null

  auto_apply             = each.value.auto_apply
  auto_apply_run_trigger = each.value.auto_apply_run_trigger
  speculative_enabled    = each.value.speculative_enabled

  file_triggers_enabled = each.value.vcs
  trigger_patterns      = each.value.trigger_patterns

  queue_all_runs      = false
  allow_destroy_plan  = true
  assessments_enabled = false

  dynamic "vcs_repo" {
    for_each = each.value.vcs ? [1] : []
    content {
      identifier                 = each.value.vcs_identifier
      github_app_installation_id = data.tfe_github_app_installation.this.id
      ingress_submodules         = false
    }
  }

  lifecycle {
    # ワークスペースの destroy は state の消失を意味する。
    # 意図せぬ削除を確実に止める。
    prevent_destroy = true
  }
}

## Output Values
output "workspace_settings" {
  description = "Current settings of the managed workspaces, for spotting drift at a glance"
  value = {
    for k, w in tfe_workspace.this :
    w.name => "tf=${w.terraform_version} exec=${w.execution_mode} auto_apply=${w.auto_apply} speculative=${w.speculative_enabled} wd=${w.working_directory}"
  }
}

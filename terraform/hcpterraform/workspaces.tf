# =============================================================================
# HCP Terraform workspaces used by this repository
#
# ここは「HCP Terraform 自体を管理する」ルート。UI でしか見えない設定が
# 長期間放置されて実害が出たため IaC 化した (詳細は README.md)。
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
    }

    # pagerduty と tailscale は VCS 連携が無く execution_mode = local。
    # HCP は state の保管場所としてのみ使われ、plan/apply は手元で走る。
    pagerduty = {
      name              = "morihaya-infra-pagerduty"
      description       = null
      project_id        = data.tfe_project.default.id
      working_directory = ""
      trigger_patterns  = []
      # 1.0.8 のままだと、手元の CLI で state を書き換える操作が
      # 「remote Terraform version と一致しない」で弾かれる。
      # execution_mode = local なので plan/apply は手元で走る。
      terraform_version      = "~>1.14.0"
      execution_mode         = "local"
      auto_apply             = false
      auto_apply_run_trigger = false
      speculative_enabled    = false
      vcs                    = false
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
      identifier                 = var.vcs_repo_identifier
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

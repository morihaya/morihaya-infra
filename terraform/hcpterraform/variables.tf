# =============================================================================
# 認証トークン (TFE_TOKEN) はここで宣言しない。
# provider が環境変数から直接読むため、Terraform 変数として宣言する必要が無い。
# 宣言してしまうと tflint-ignore 付きのダミー宣言が増えるだけになる。
# =============================================================================

variable "tfe_organization" {
  description = "HCP Terraform organization that owns the workspaces"
  type        = string
  default     = "morihaya"
}

# このルートは org 内の他リポジトリのワークスペースも管理するため、
# VCS のバックエンドは workspaces.tf の vcs_identifier で個別に指定する。
# ここにあるのは本リポジトリのワークスペースが使う値。
variable "vcs_repo_identifier" {
  description = "GitHub repository backing the VCS-driven workspaces of this repository"
  type        = string
  default     = "morihaya/morihaya-infra"
}

variable "github_app_installation_name" {
  description = "Name of the GitHub App installation used for VCS connections. Resolved to an id by a data source so no opaque identifier lives in this public repository."
  type        = string
  default     = "morihaya"
}

variable "homelab_agent_pool_name" {
  description = "Agent pool that runs the homelab workspace (the agent VM lives on the Proxmox cluster)"
  type        = string
  default     = "homelab01"
}

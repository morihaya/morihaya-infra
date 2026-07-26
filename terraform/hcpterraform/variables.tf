# =============================================================================
# Variables provided by the HCP Terraform workspace
# =============================================================================
variable "TFE_TOKEN" {
  description = "HCP Terraform API token with org owner permissions. Set as a sensitive Terraform variable on the morihaya-infra workspace. Leave empty to fall back to the provider's own discovery (TFE_TOKEN environment variable, then the Terraform CLI config credentials) — that is what local runs use."
  type        = string
  sensitive   = true
  default     = ""
}

variable "tfe_organization" {
  description = "HCP Terraform organization that owns the workspaces"
  type        = string
  default     = "morihaya"
}

variable "vcs_repo_identifier" {
  description = "GitHub repository backing the VCS-driven workspaces"
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

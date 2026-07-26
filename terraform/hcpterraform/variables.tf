# =============================================================================
# Variables provided by the HCP Terraform workspace
# =============================================================================
# tflint-ignore: terraform_unused_declarations
variable "TFE_TOKEN" {
  description = "HCP Terraform API token with org owner permissions (also consumed by the provider via environment variable)"
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

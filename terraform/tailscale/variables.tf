variable "tailscale_api_key" {
  description = "Tailscale API key"
  type        = string
  sensitive   = true
}

variable "tailscale_tailnet" {
  description = "Tailnet name"
  type        = string
}

variable "mail_own" {
  description = "Owner email address referenced in the ACL admin group"
  type        = string
}

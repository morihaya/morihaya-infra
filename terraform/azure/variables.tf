variable "ARM_SUBSCRIPTION_ID" {
  description = "For Azure provider"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ARM_TENANT_ID" {
  description = "For Azure provider"
  type        = string
  default     = ""
  sensitive   = true
}

variable "TFC_AZURE_PROVIDER_AUTH" {
  description = "For Azure provider"
  type        = string
  default     = ""
  sensitive   = true
}

variable "TFC_AZURE_RUN_CLIENT_ID" {
  description = "For Azure provider"
  type        = string
  default     = ""
  sensitive   = true
}

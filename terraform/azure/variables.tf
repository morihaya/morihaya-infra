# These variables are consumed by the azurerm provider / HCP Terraform
# dynamic credentials, not referenced directly in this configuration.
# Declaring them here silences the "undeclared variable" warnings.

# tflint-ignore: terraform_unused_declarations
variable "ARM_SUBSCRIPTION_ID" {
  description = "For Azure provider"
  type        = string
  default     = ""
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "ARM_TENANT_ID" {
  description = "For Azure provider"
  type        = string
  default     = ""
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "TFC_AZURE_PROVIDER_AUTH" {
  description = "For Azure provider"
  type        = string
  default     = ""
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "TFC_AZURE_RUN_CLIENT_ID" {
  description = "For Azure provider"
  type        = string
  default     = ""
  sensitive   = true
}

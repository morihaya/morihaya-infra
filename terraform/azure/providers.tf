# Authentication is handled via dynamic provider credentials in HCP Terraform
# (TFC_AZURE_PROVIDER_AUTH / TFC_AZURE_RUN_CLIENT_ID workspace variables).
provider "azurerm" {
  features {}
}

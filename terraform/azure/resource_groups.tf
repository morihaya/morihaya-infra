resource "azurerm_resource_group" "eastus" {
  name     = "morihaya-infra-rg-eastus"
  location = "East US"
  tags     = local.common_tags
}

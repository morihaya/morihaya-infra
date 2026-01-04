resource "azurerm_resource_group" "eastus" {
  name     = "morihaya-infra-rg-eastus"
  location = "East US"
  tags     = local.common_tags
}

resource "azurerm_resource_group" "japaneast" {
  name     = "morihaya-infra-rg-japaneast"
  location = "Japan East"
  tags     = local.common_tags
}

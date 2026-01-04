terraform {
  cloud {
    organization = "morihaya"
    workspaces {
      name = "morihaya-infra-azure"
    }
  }
}

provider "azurerm" {
  features {}
}

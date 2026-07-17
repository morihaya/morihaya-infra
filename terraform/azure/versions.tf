terraform {
  required_version = ">= 1.5.0"

  cloud {
    organization = "morihaya"

    workspaces {
      name = "morihaya-infra-azure"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.57"
    }
  }
}

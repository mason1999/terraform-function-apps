terraform {
  required_version = ">=1.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.5"
    }
  }
}

provider "azurerm" {
  features {}
  storage_use_azuread = true
}

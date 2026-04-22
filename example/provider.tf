terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.70.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azurerm" {
  alias           = "dns"
  subscription_id = "ed302caf-ec27-4c64-a05e-85731c3ce90e"
  features {}
}

provider "azurerm" {
  alias           = "private_dns"
  subscription_id = "ed302caf-ec27-4c64-a05e-85731c3ce90e"
  features {}
}

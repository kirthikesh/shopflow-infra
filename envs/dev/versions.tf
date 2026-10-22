terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.10"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "azurerm" {
    key = "envs/dev.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      # Dev only: purge deleted vaults on destroy so the name can be reused straight away.
      purge_soft_delete_on_destroy = true
    }
  }

  resource_provider_registrations = "none"
  resource_providers_to_register = [
    "Microsoft.Network",
    "Microsoft.KeyVault",
    "Microsoft.Insights",
    "Microsoft.ContainerService",
    "Microsoft.ManagedIdentity",
    "Microsoft.OperationalInsights",
    "Microsoft.OperationsManagement",
    "Microsoft.ServiceBus",
  ]
}

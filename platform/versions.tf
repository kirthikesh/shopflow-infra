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

  # Partial config: the storage account details come from generated/backend.hcl
  # (written by the bootstrap layer) via `terraform init -backend-config=...`.
  backend "azurerm" {
    key = "platform.tfstate"
  }
}

provider "azurerm" {
  features {}

  resource_provider_registrations = "none"
  resource_providers_to_register = [
    "Microsoft.Network",
    "Microsoft.ContainerRegistry",
    "Microsoft.OperationalInsights",
    "Microsoft.Insights",
    "Microsoft.Consumption",
    "Microsoft.PolicyInsights",
  ]
}

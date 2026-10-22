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
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
  # No backend block: this layer uses local state on purpose.
}

provider "azurerm" {
  features {}

  # The account has shared keys disabled, so the provider must use Entra ID for blob data.
  storage_use_azuread = true

  # AzureRM 5.x registers no resource providers by default. Register only what we use.
  resource_provider_registrations = "none"
  resource_providers_to_register  = ["Microsoft.Storage"]
}

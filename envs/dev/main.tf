# Dev environment: a spoke VNet peered to the hub, and the environment's Key Vault.
# Phase 3 adds the private AKS cluster to this layer.

data "terraform_remote_state" "platform" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.state_backend.resource_group_name
    storage_account_name = var.state_backend.storage_account_name
    container_name       = var.state_backend.container_name
    key                  = "platform.tfstate"
    use_azuread_auth     = true
  }
}

locals {
  name_prefix = "shopflow"
  platform    = data.terraform_remote_state.platform.outputs
  location    = local.platform.location

  tags = {
    project    = "shopflow"
    env        = var.environment
    owner      = var.owner
    managed_by = "terraform"
    layer      = "env"
  }
}

resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

resource "azurerm_resource_group" "env" {
  name     = "rg-${local.name_prefix}-${var.environment}-${var.location_short}"
  location = local.location
  tags     = local.tags
}

module "spoke_network" {
  source = "../../modules/spoke-network"

  name_prefix             = local.name_prefix
  environment             = var.environment
  location                = local.location
  location_short          = var.location_short
  resource_group_name     = azurerm_resource_group.env.name
  address_space           = var.address_space
  hub_vnet_id             = local.platform.hub_vnet_id
  hub_vnet_name           = local.platform.hub_vnet_name
  hub_resource_group_name = local.platform.resource_group_name
  tags                    = local.tags
}

# Link the hub's private DNS zones to this spoke so private endpoints resolve here too.
resource "azurerm_private_dns_zone_virtual_network_link" "spoke" {
  for_each = local.platform.private_dns_zone_ids

  name                 = "link-${var.environment}"
  private_dns_zone_id  = each.value
  virtual_network_id   = module.spoke_network.vnet_id
  registration_enabled = false
  tags                 = local.tags
}

module "key_vault" {
  source = "../../modules/key-vault"

  name                       = "kv-${local.name_prefix}-${var.environment}-${random_string.suffix.result}"
  location                   = local.location
  resource_group_name        = azurerm_resource_group.env.name
  enable_private_endpoint    = var.enable_private_endpoints
  private_endpoint_subnet_id = module.spoke_network.subnet_ids.private_endpoints
  private_dns_zone_id        = local.platform.private_dns_zone_ids.key_vault
  log_analytics_workspace_id = local.platform.log_analytics_workspace_id
  enable_diagnostics         = true
  tags                       = local.tags
}

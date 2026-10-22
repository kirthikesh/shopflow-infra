# Platform layer: shared services used by every environment.
#   hub network, private DNS zones, container registry, Log Analytics,
#   subscription budget and policy guardrails.

data "azurerm_subscription" "current" {}

locals {
  name_prefix = "shopflow"
  tags = {
    project    = "shopflow"
    env        = "shared"
    owner      = var.owner
    managed_by = "terraform"
    layer      = "platform"
  }

  private_dns_zones = {
    acr       = "privatelink.azurecr.io"
    key_vault = "privatelink.vaultcore.azure.net"
  }
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "platform" {
  name     = "rg-${local.name_prefix}-platform-${var.location_short}"
  location = var.location
  tags     = local.tags
}

module "hub_network" {
  source = "../modules/hub-network"

  name_prefix         = local.name_prefix
  location            = var.location
  location_short      = var.location_short
  resource_group_name = azurerm_resource_group.platform.name
  address_space       = var.hub_address_space
  tags                = local.tags
}

module "private_dns" {
  source = "../modules/private-dns"

  resource_group_name = azurerm_resource_group.platform.name
  zones               = values(local.private_dns_zones)
  vnet_ids            = { hub = module.hub_network.vnet_id }
  tags                = local.tags
}

module "log_analytics" {
  source = "../modules/log-analytics"

  name_prefix         = local.name_prefix
  location            = var.location
  location_short      = var.location_short
  resource_group_name = azurerm_resource_group.platform.name
  tags                = local.tags
}

module "container_registry" {
  source = "../modules/container-registry"

  name                       = "acr${local.name_prefix}${random_string.suffix.result}"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.platform.name
  sku                        = var.acr_sku
  enable_private_endpoint    = var.enable_private_endpoints
  private_endpoint_subnet_id = module.hub_network.subnet_ids.private_endpoints
  private_dns_zone_id        = module.private_dns.zone_ids[local.private_dns_zones.acr]
  log_analytics_workspace_id = module.log_analytics.id
  enable_diagnostics         = true
  tags                       = local.tags
}

module "budget" {
  source = "../modules/budget"

  name_prefix     = local.name_prefix
  subscription_id = data.azurerm_subscription.current.id
  amount          = var.budget_amount
  start_date      = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  contact_emails  = var.budget_contact_emails
}

module "policy" {
  source = "../modules/policy-baseline"

  name_prefix     = local.name_prefix
  subscription_id = data.azurerm_subscription.current.id
}

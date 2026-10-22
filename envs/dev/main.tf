# Dev environment: a spoke VNet peered to the hub, the environment's Key Vault,
# and (when aks_enabled = true) the AKS cluster and Service Bus namespace.
# The last two are the expensive parts, so `make aks-down` switches just them off.

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
  admin_object_ids           = var.admin_object_ids
  tags                       = local.tags
}

# ---- Phase 3: compute and messaging (switchable to save money) ----------

module "aks" {
  source = "../../modules/aks"
  count  = var.aks_enabled ? 1 : 0

  name                            = "aks-${local.name_prefix}-${var.environment}-${var.location_short}"
  location                        = local.location
  resource_group_name             = azurerm_resource_group.env.name
  node_subnet_id                  = module.spoke_network.subnet_ids.aks_nodes
  node_vm_size                    = var.aks_node_vm_size
  api_server_private              = var.aks_api_server_private
  api_server_authorized_ip_ranges = var.aks_api_server_authorized_ip_ranges
  admin_object_ids                = var.admin_object_ids
  acr_id                          = local.platform.acr_id
  log_analytics_workspace_id      = local.platform.log_analytics_workspace_id
  tags                            = local.tags
}

module "service_bus" {
  source = "../../modules/service-bus"
  count  = var.aks_enabled ? 1 : 0

  name                = "sb-${local.name_prefix}-${var.environment}-${random_string.suffix.result}"
  location            = local.location
  resource_group_name = azurerm_resource_group.env.name
  tags                = local.tags
}

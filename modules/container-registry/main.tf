# Azure Container Registry for all ShopFlow images.
# Basic SKU by default (about €5/month). Private endpoints need Premium (about €45/month),
# so they are switched on with enable_private_endpoint when the cluster goes private.

resource "azurerm_container_registry" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku

  # No shared admin username/password. AKS pulls with its managed identity,
  # and pipelines push with Entra ID.
  admin_enabled = false

  public_network_access_enabled = !var.enable_private_endpoint
  tags                          = var.tags
}

resource "azurerm_private_endpoint" "this" {
  count = var.enable_private_endpoint ? 1 : 0

  name                = "pe-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.name}"
    private_connection_resource_id = azurerm_container_registry.this.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  lifecycle {
    precondition {
      condition     = var.sku == "Premium"
      error_message = "ACR private endpoints require the Premium SKU. Set sku = \"Premium\"."
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  count = var.enable_diagnostics ? 1 : 0

  name                       = "to-log-analytics"
  target_resource_id         = azurerm_container_registry.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "audit"
  }
}

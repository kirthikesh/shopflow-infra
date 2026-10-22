# One Log Analytics workspace for platform and app logs (AKS Container Insights in Phase 3,
# Key Vault audit logs now). A daily cap stops a noisy app from running up a bill.

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.name_prefix}-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days
  daily_quota_gb      = var.daily_quota_gb
  tags                = var.tags
}

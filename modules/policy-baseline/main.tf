# Guardrails assigned at subscription scope, using Azure's built-in policies:
#   1. Resources may only be created in the allowed regions.
#   2. Every resource group should carry a "project" tag (needed for cost reporting).
#      Audit-only by default: Azure itself creates untagged resource groups
#      (NetworkWatcherRG, the AKS node group), and a deny would break those.
# Built-in definition IDs are the same in every Azure tenant.

data "azurerm_policy_definition" "allowed_locations" {
  name = "e56962a6-4747-49cd-b67b-bf8b01975c4c"
}

data "azurerm_policy_definition" "require_rg_tag" {
  name = "96670d01-0a4d-4649-9c89-2d3abc0a5025"
}

resource "azurerm_subscription_policy_assignment" "allowed_locations" {
  name                 = "${var.name_prefix}-allowed-locations"
  display_name         = "ShopFlow: allowed locations"
  subscription_id      = var.subscription_id
  policy_definition_id = data.azurerm_policy_definition.allowed_locations.id
  enforce              = var.enforce

  parameters = jsonencode({
    listOfAllowedLocations = { value = var.allowed_locations }
  })
}

resource "azurerm_subscription_policy_assignment" "require_rg_tag" {
  name                 = "${var.name_prefix}-require-project-tag"
  display_name         = "ShopFlow: resource groups need a project tag"
  subscription_id      = var.subscription_id
  policy_definition_id = data.azurerm_policy_definition.require_rg_tag.id
  enforce              = var.enforce_tag_policy

  parameters = jsonencode({
    tagName = { value = "project" }
  })
}

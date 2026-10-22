output "assignment_ids" {
  value = [
    azurerm_subscription_policy_assignment.allowed_locations.id,
    azurerm_subscription_policy_assignment.require_rg_tag.id,
  ]
}

output "storage_account_name" {
  description = "Storage account that holds Terraform state."
  value       = azurerm_storage_account.state.name
}

output "resource_group_name" {
  value = azurerm_resource_group.state.name
}

output "container_name" {
  value = azurerm_storage_container.state.name
}

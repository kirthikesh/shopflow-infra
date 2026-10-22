output "resource_group_name" {
  value = azurerm_resource_group.env.name
}

output "spoke_vnet_id" {
  value = module.spoke_network.vnet_id
}

output "spoke_subnet_ids" {
  value = module.spoke_network.subnet_ids
}

output "key_vault_name" {
  value = module.key_vault.name
}

output "key_vault_uri" {
  value = module.key_vault.uri
}

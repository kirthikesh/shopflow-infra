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

output "aks_name" {
  value = one(module.aks[*].name)
}

output "aks_oidc_issuer_url" {
  value = one(module.aks[*].oidc_issuer_url)
}

output "acr_login_server" {
  value = local.platform.acr_login_server
}

output "servicebus_namespace" {
  value = one(module.service_bus[*].namespace_name)
}

output "servicebus_connection_string" {
  value     = one(module.service_bus[*].app_connection_string)
  sensitive = true
}

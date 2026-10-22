# Read by the environment layers through terraform_remote_state.

output "resource_group_name" {
  value = azurerm_resource_group.platform.name
}

output "location" {
  value = var.location
}

output "hub_vnet_id" {
  value = module.hub_network.vnet_id
}

output "hub_vnet_name" {
  value = module.hub_network.vnet_name
}

output "hub_subnet_ids" {
  value = module.hub_network.subnet_ids
}

output "private_dns_zone_ids" {
  description = "Keyed by service: acr, key_vault."
  value = {
    for key, zone in local.private_dns_zones : key => module.private_dns.zone_ids[zone]
  }
}

output "private_dns_zone_names" {
  value = local.private_dns_zones
}

output "log_analytics_workspace_id" {
  value = module.log_analytics.id
}

output "acr_id" {
  value = module.container_registry.id
}

output "acr_login_server" {
  value = module.container_registry.login_server
}

output "management_nsg_name" {
  value = module.hub_network.management_nsg_name
}

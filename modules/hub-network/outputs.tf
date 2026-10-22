output "vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "vnet_name" {
  value = azurerm_virtual_network.hub.name
}

output "address_space" {
  value = var.address_space
}

output "subnet_ids" {
  value = {
    bastion           = azurerm_subnet.bastion.id
    management        = azurerm_subnet.management.id
    private_endpoints = azurerm_subnet.private_endpoints.id
  }
}

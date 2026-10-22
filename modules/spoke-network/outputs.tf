output "vnet_id" {
  value = azurerm_virtual_network.spoke.id
}

output "vnet_name" {
  value = azurerm_virtual_network.spoke.name
}

output "subnet_ids" {
  value = {
    aks_nodes         = azurerm_subnet.aks_nodes.id
    ingress           = azurerm_subnet.ingress.id
    private_endpoints = azurerm_subnet.private_endpoints.id
  }
}

output "public_ip" {
  value = azurerm_public_ip.this.ip_address
}

output "private_ip" {
  value = azurerm_network_interface.this.private_ip_address
}

output "admin_username" {
  value = var.admin_username
}

output "principal_id" {
  description = "Managed identity object ID, granted rights in Phase 5."
  value       = azurerm_linux_virtual_machine.this.identity[0].principal_id
}

output "namespace_name" {
  value = azurerm_servicebus_namespace.this.name
}

output "namespace_id" {
  value = azurerm_servicebus_namespace.this.id
}

output "app_connection_string" {
  description = "Send/listen connection string for the apps. Sensitive: never print it in CI logs."
  value       = azurerm_servicebus_namespace_authorization_rule.app.primary_connection_string
  sensitive   = true
}

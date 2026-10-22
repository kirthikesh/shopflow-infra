output "name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "id" {
  value = azurerm_kubernetes_cluster.this.id
}

output "oidc_issuer_url" {
  description = "Used in Phase 7 to federate Kubernetes service accounts with Azure identities."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

output "node_resource_group" {
  value = azurerm_kubernetes_cluster.this.node_resource_group
}

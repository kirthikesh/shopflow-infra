# AKS cluster for one environment.
#
#   Networking  Azure CNI Overlay with the Cilium data plane and network policy.
#               Nodes get IPs from the spoke subnet; pods get IPs from a private
#               overlay range, so the VNet never runs out of addresses.
#   Identity    A user-assigned identity for the control plane (so we can grant it
#               rights on the subnet BEFORE the cluster exists), Workload Identity
#               for pods, and Entra ID for kubectl with local accounts switched off.
#   Add-ons     Container Insights (logs to Log Analytics) and the Key Vault
#               Secrets Store CSI driver.

data "azurerm_client_config" "current" {}

resource "azurerm_user_assigned_identity" "control_plane" {
  name                = "id-${var.name}-control-plane"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# The cluster manages load balancers and NICs in our subnet, so it needs
# Network Contributor there. Granting it first avoids a race on creation.
resource "azurerm_role_assignment" "control_plane_network" {
  scope                = var.node_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.name
  node_resource_group = "${var.resource_group_name}-aks-nodes"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"
  tags                = var.tags

  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"

  # Security
  local_account_disabled       = true
  oidc_issuer_enabled          = true
  workload_identity_enabled    = true
  private_cluster_enabled      = var.api_server_private
  image_cleaner_enabled        = true
  image_cleaner_interval_hours = 48

  # While the API server is public, only these IPs can reach it.
  dynamic "api_server_access_profile" {
    for_each = var.api_server_private ? [] : [1]
    content {
      authorized_ip_ranges = var.api_server_authorized_ip_ranges
    }
  }

  azure_active_directory_role_based_access_control {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    azure_rbac_enabled = true
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane.id]
  }

  # AzureRM 5.x requires this block. Manual = we define node pools ourselves.
  node_provisioning_profile {
    mode = "Manual"
  }

  default_node_pool {
    name                        = "system"
    vm_size                     = var.node_vm_size
    vnet_subnet_id              = var.node_subnet_id
    auto_scaling_enabled        = true
    min_count                   = var.node_min_count
    max_count                   = var.node_max_count
    os_disk_type                = "Managed"
    os_disk_size_gb             = 64
    temporary_name_for_rotation = "systemtmp"
    tags                        = var.tags

    upgrade_settings {
      max_surge = "10%"
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = cidrhost(var.service_cidr, 10)
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  oms_agent {
    log_analytics_workspace_id      = var.log_analytics_workspace_id
    msi_auth_for_monitoring_enabled = true
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  depends_on = [azurerm_role_assignment.control_plane_network]

  lifecycle {
    # Patch upgrades happen automatically; don't fight them on the next plan.
    ignore_changes = [kubernetes_version, default_node_pool[0].node_count]
  }
}

# Nodes pull images from ACR with the kubelet's managed identity. No registry password.
resource "azurerm_role_assignment" "acr_pull" {
  scope                            = var.acr_id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

# Whoever runs Terraform gets cluster-admin through Entra ID (there is no local admin).
resource "azurerm_role_assignment" "deployer_cluster_admin" {
  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Spoke VNet for one environment (dev, prod...), peered to the hub.
#   - snet-aks-nodes          AKS node pool (Phase 3), sized /20 for Azure CNI Overlay
#   - snet-ingress            internal load balancer / ingress controller
#   - snet-private-endpoints  private endpoints for this environment's Key Vault, database...

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-${var.name_prefix}-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "aks_nodes" {
  name                 = "snet-aks-nodes"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.address_space, 4, 0)] # /20
}

resource "azurerm_subnet" "ingress" {
  name                 = "snet-ingress"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.address_space, 8, 16)] # /24
}

resource "azurerm_subnet" "private_endpoints" {
  name                              = "snet-private-endpoints"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.spoke.name
  address_prefixes                  = [cidrsubnet(var.address_space, 8, 17)] # /24
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_network_security_group" "this" {
  for_each = toset(["aks-nodes", "ingress", "pe"])

  name                = "nsg-${var.name_prefix}-${var.environment}-${each.key}-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "aks_nodes" {
  subnet_id                 = azurerm_subnet.aks_nodes.id
  network_security_group_id = azurerm_network_security_group.this["aks-nodes"].id
}

resource "azurerm_subnet_network_security_group_association" "ingress" {
  subnet_id                 = azurerm_subnet.ingress.id
  network_security_group_id = azurerm_network_security_group.this["ingress"].id
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.this["pe"].id
}

# Peering is one-way in Azure, so it needs a link in each direction.
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-${var.environment}-to-hub"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = var.hub_vnet_id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "peer-hub-to-${var.environment}"
  resource_group_name       = var.hub_resource_group_name
  virtual_network_name      = var.hub_vnet_name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id
  allow_forwarded_traffic   = true
}

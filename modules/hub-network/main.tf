# Hub VNet: shared services every environment connects to.
#   - AzureBastionSubnet  reserved for Azure Bastion (not deployed by default: it costs ~€130/month)
#   - snet-management     jump box and self-hosted build agents (Phase 4, configured by Ansible)
#   - snet-private-endpoints  private endpoints for shared services such as ACR

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.name_prefix}-hub-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "bastion" {
  # Azure requires this exact name.
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.address_space, 10, 0)] # /26
}

resource "azurerm_subnet" "management" {
  name                 = "snet-management"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.address_space, 8, 1)] # /24
}

resource "azurerm_subnet" "private_endpoints" {
  name                              = "snet-private-endpoints"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.hub.name
  address_prefixes                  = [cidrsubnet(var.address_space, 8, 2)] # /24
  private_endpoint_network_policies = "Enabled"
}

# Management subnet: SSH only from inside the VNet (via Bastion or VPN), nothing from the internet.
resource "azurerm_network_security_group" "management" {
  name                = "nsg-${var.name_prefix}-management-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "allow-ssh-from-vnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-internet-inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.management.id
}

resource "azurerm_network_security_group" "private_endpoints" {
  name                = "nsg-${var.name_prefix}-hub-pe-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}

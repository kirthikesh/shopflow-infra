# Management layer: the jump box / build agent VM in the hub.
# Separate state, so `make jumpbox-down` removes only this and nothing shared.

data "terraform_remote_state" "platform" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.state_backend.resource_group_name
    storage_account_name = var.state_backend.storage_account_name
    container_name       = var.state_backend.container_name
    key                  = "platform.tfstate"
    use_azuread_auth     = true
  }
}

locals {
  platform = data.terraform_remote_state.platform.outputs
  tags = {
    project    = "shopflow"
    env        = "shared"
    owner      = var.owner
    managed_by = "terraform"
    layer      = "management"
  }
}

resource "azurerm_resource_group" "mgmt" {
  name     = "rg-shopflow-mgmt-${var.location_short}"
  location = local.platform.location
  tags     = local.tags
}

module "jumpbox" {
  source = "../modules/jumpbox"

  name                = "vm-shopflow-jump-${var.location_short}"
  location            = local.platform.location
  resource_group_name = azurerm_resource_group.mgmt.name
  subnet_id           = local.platform.hub_subnet_ids.management
  vm_size             = var.vm_size
  ssh_public_key      = var.ssh_public_key
  tags                = local.tags
}

# SSH from the admin's IP only. Priority 110 sits above the subnet's
# "deny internet" rule at 4000, so everything else stays blocked.
resource "azurerm_network_security_rule" "ssh_from_admin" {
  name                        = "allow-ssh-from-admin"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.admin_ip_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = local.platform.resource_group_name
  network_security_group_name = local.platform.management_nsg_name
}

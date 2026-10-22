# Jump box / self-hosted build agent in the hub's management subnet.
#   - SSH keys only, no passwords; NSG lets in SSH from the admin's IP only
#   - System-assigned managed identity (used by the pipeline agent in Phase 5)
#   - Shuts itself down every evening so a forgotten VM can't run all night
#   - Supports confidential VM sizes (DC*/EC*), which some new subscriptions are limited to
# Configuration (hardening, tools, agent) is done by Ansible, not cloud-init.

locals {
  # Confidential sizes need a confidential OS image, Secure Boot and vTPM.
  confidential = can(regex("^Standard_(DC|EC)", var.vm_size))
}

resource "azurerm_public_ip" "this" {
  name                = "pip-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "this" {
  name                = "nic-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.this.id
  }
}

resource "azurerm_linux_virtual_machine" "this" {
  name                  = var.name
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.this.id]
  tags                  = var.tags

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  identity {
    type = "SystemAssigned"
  }

  secure_boot_enabled = local.confidential ? true : null
  vtpm_enabled        = local.confidential ? true : null

  os_disk {
    caching                  = "ReadWrite"
    storage_account_type     = "StandardSSD_LRS"
    disk_size_gb             = 64
    security_encryption_type = local.confidential ? "VMGuestStateOnly" : null
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = local.confidential ? "cvm" : "server"
    version   = "latest"
  }

  boot_diagnostics {} # managed storage, so the serial console works if SSH breaks
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "this" {
  virtual_machine_id    = azurerm_linux_virtual_machine.this.id
  location              = var.location
  enabled               = true
  daily_recurrence_time = var.auto_shutdown_time
  timezone              = "GMT Standard Time" # Dublin

  notification_settings {
    enabled = false
  }
}

# Bootstrap: the storage account that holds every other layer's Terraform state.
#
# This layer is applied once, with LOCAL state (the chicken-and-egg problem:
# remote state needs a storage account to exist first). Its own state file is
# small and is kept out of git.

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

locals {
  tags = {
    project    = "shopflow"
    env        = "shared"
    managed_by = "terraform"
    layer      = "bootstrap"
  }
}

resource "azurerm_resource_group" "state" {
  name     = "rg-shopflow-tfstate-${var.location_short}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "state" {
  name                     = "stshopflowtf${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # Security: no access keys, no public blobs, modern TLS only.
  # Terraform authenticates with your Entra ID login instead of a shared key.
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  default_to_oauth_authentication = true

  blob_properties {
    # Every state write keeps the previous version, so a bad apply can be rolled back.
    versioning_enabled = true

    delete_retention_policy {
      days = 14
    }
    container_delete_retention_policy {
      days = 14
    }
  }

  tags = local.tags
}

resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

# Lets whoever runs Terraform read and write state through Entra ID.
resource "azurerm_role_assignment" "state_contributor" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Stop anyone deleting the state account by accident (including `terraform destroy` here).
resource "azurerm_management_lock" "state" {
  name       = "do-not-delete-terraform-state"
  scope      = azurerm_storage_account.state.id
  lock_level = "CanNotDelete"
  notes      = "Holds Terraform state for every ShopFlow layer."
}

# Write the settings the other layers need, so nobody copies names by hand.
resource "local_file" "backend_config" {
  filename        = "${path.module}/../generated/backend.hcl"
  file_permission = "0644"
  content         = <<-EOT
    resource_group_name  = "${azurerm_resource_group.state.name}"
    storage_account_name = "${azurerm_storage_account.state.name}"
    container_name       = "${azurerm_storage_container.state.name}"
    use_azuread_auth     = true
  EOT
}

resource "local_file" "state_vars" {
  filename        = "${path.module}/../generated/state.tfvars.json"
  file_permission = "0644"
  content = jsonencode({
    state_backend = {
      resource_group_name  = azurerm_resource_group.state.name
      storage_account_name = azurerm_storage_account.state.name
      container_name       = azurerm_storage_container.state.name
    }
  })
}

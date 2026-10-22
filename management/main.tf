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

# ---- Phase 5: what the pipeline agent is allowed to do ---------------------
#
# The VM's managed identity is the pipelines' only credential: no service principal
# secret, no stored token, nothing to rotate. Terraform manages the whole landing
# zone, so the identity is powerful. That is why the VM is hardened, accepts SSH only
# from the admin, and every apply waits for a human approval in Azure DevOps.
#
# It is NOT Owner. It can grant only the four roles our modules hand out
# (constrained delegation), so a compromised pipeline cannot make itself or
# anyone else Owner.

data "azurerm_subscription" "current" {}

data "azurerm_storage_account" "state" {
  name                = var.state_backend.storage_account_name
  resource_group_name = var.state_backend.resource_group_name
}

data "azurerm_role_definition" "delegable" {
  for_each = toset([
    "AcrPull",                                     # AKS kubelet -> registry
    "Network Contributor",                         # AKS control plane -> node subnet
    "Azure Kubernetes Service RBAC Cluster Admin", # admins -> cluster
    "Key Vault Secrets Officer",                   # admins -> vault
  ])
  name  = each.value
  scope = data.azurerm_subscription.current.id
}

locals {
  agent_principal_id = module.jumpbox.principal_id
  delegable_role_ids = join(", ", [for r in data.azurerm_role_definition.delegable : basename(r.role_definition_id)])

  agent_roles = {
    contributor = { scope = data.azurerm_subscription.current.id, role = "Contributor" }
    policy      = { scope = data.azurerm_subscription.current.id, role = "Resource Policy Contributor" }
    state       = { scope = data.azurerm_storage_account.state.id, role = "Storage Blob Data Contributor" }
    acr_push    = { scope = local.platform.acr_id, role = "AcrPush" }
  }
}

resource "azurerm_role_assignment" "agent" {
  for_each = local.agent_roles

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = local.agent_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "agent_rbac_admin" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = local.agent_principal_id
  principal_type       = "ServicePrincipal"
  description          = "Pipeline agent may assign or remove only: AcrPull, Network Contributor, AKS RBAC Cluster Admin, Key Vault Secrets Officer."

  condition_version = "2.0"
  condition         = <<-EOT
    (
      (!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'}))
      OR
      (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.delegable_role_ids}})
    )
    AND
    (
      (!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'}))
      OR
      (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.delegable_role_ids}})
    )
  EOT
}

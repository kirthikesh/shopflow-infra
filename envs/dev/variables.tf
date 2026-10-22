variable "environment" {
  type    = string
  default = "dev"
}

variable "location_short" {
  type    = string
  default = "neu"
}

variable "address_space" {
  description = "Spoke CIDR. dev = 10.10.0.0/16, prod = 10.20.0.0/16."
  type        = string
  default     = "10.10.0.0/16"
}

variable "enable_private_endpoints" {
  description = "Put Key Vault behind a private endpoint. Off until there's a VM or cluster inside the VNet to reach it from."
  type        = bool
  default     = false
}

variable "aks_enabled" {
  description = "Create the AKS cluster and Service Bus. false tears down just those (they are what costs money)."
  type        = bool
  default     = true
}

variable "aks_node_vm_size" {
  type    = string
  default = "Standard_D2s_v5"
}

variable "aks_api_server_private" {
  description = "Phase 3: false (public API locked to your IP). Phase 4 switches to true once the jump box exists."
  type        = bool
  default     = false
}

variable "aks_api_server_authorized_ip_ranges" {
  description = "Your public IP as a /32. The Makefile fills this in automatically."
  type        = list(string)
  default     = []
}

variable "owner" {
  type    = string
  default = "kirthikesh"
}

variable "state_backend" {
  description = "Where the platform layer's state lives. Supplied by generated/state.tfvars.json."
  type = object({
    resource_group_name  = string
    storage_account_name = string
    container_name       = string
  })
}

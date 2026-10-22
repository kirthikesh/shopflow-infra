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
  description = "New subscriptions only allow some sizes per region; this one was allowed and had quota (see README)."
  type        = string
  default     = "Standard_EC2ads_v5"
}

variable "aks_api_server_private" {
  description = "Phase 3: false (public API locked to your IP). Phase 4 switches to true once the jump box exists."
  type        = bool
  default     = false
}

variable "aks_api_server_authorized_ip_ranges" {
  description = "Who can reach the AKS API: your IP and the pipeline agent's. Written by scripts/access-vars.sh."
  type        = list(string)
  default     = []
}

variable "admin_object_ids" {
  description = "Cluster and Key Vault admins keyed by role: owner (you) and pipeline (the agent). Written by scripts/access-vars.sh."
  type        = map(string)

  validation {
    condition     = contains(keys(var.admin_object_ids), "owner")
    error_message = "admin_object_ids needs an \"owner\" entry, or you would lock yourself out of the cluster."
  }
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

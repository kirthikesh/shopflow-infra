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

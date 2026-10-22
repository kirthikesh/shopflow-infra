variable "location_short" {
  type    = string
  default = "neu"
}

variable "vm_size" {
  description = "Must be a size your subscription allows (az vm list-skus)."
  type        = string
  default     = "Standard_EC2ads_v5"
}

variable "ssh_public_key" {
  description = "Your public key. The Makefile reads it from ~/.ssh."
  type        = string
}

variable "admin_ip_cidrs" {
  description = "Where SSH is allowed from. The Makefile fills in your public IP."
  type        = list(string)

  validation {
    condition     = length(var.admin_ip_cidrs) > 0 && alltrue([for c in var.admin_ip_cidrs : can(cidrhost(c, 0))])
    error_message = "Give at least one CIDR, e.g. [\"203.0.113.7/32\"]."
  }
}

variable "owner" {
  type    = string
  default = "kirthikesh"
}

variable "state_backend" {
  type = object({
    resource_group_name  = string
    storage_account_name = string
    container_name       = string
  })
}

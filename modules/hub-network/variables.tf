variable "name_prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "location_short" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "address_space" {
  description = "Hub VNet CIDR. Must be a /16 so the subnet maths works."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.address_space, 0)) && endswith(var.address_space, "/16")
    error_message = "address_space must be a valid /16 CIDR, for example 10.0.0.0/16."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}

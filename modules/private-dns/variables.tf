variable "resource_group_name" {
  type = string
}

variable "zones" {
  description = "Private DNS zone names, e.g. privatelink.azurecr.io."
  type        = list(string)
}

variable "vnet_ids" {
  description = "VNets to link each zone to, keyed by a short name (e.g. { hub = <id> })."
  type        = map(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}

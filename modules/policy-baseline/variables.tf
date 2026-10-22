variable "name_prefix" {
  type = string
}

variable "subscription_id" {
  description = "Full subscription resource ID, e.g. /subscriptions/<guid>."
  type        = string
}

variable "allowed_locations" {
  description = "Regions resources may be created in. 'global' is needed for things like DNS zones."
  type        = list(string)
  default     = ["northeurope", "westeurope", "global"]
}

variable "enforce" {
  description = "Enforce the allowed-locations policy. false = audit only (report without blocking)."
  type        = bool
  default     = true
}

variable "enforce_tag_policy" {
  description = "Enforce the resource-group tag policy. Audit only by default (see main.tf)."
  type        = bool
  default     = false
}

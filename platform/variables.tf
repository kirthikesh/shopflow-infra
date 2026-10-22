variable "location" {
  type    = string
  default = "northeurope" # Dublin
}

variable "location_short" {
  type    = string
  default = "neu"
}

variable "hub_address_space" {
  type    = string
  default = "10.0.0.0/16"
}

variable "acr_sku" {
  description = "Basic is enough until the cluster goes private; private endpoints need Premium."
  type        = string
  default     = "Basic"
}

variable "enable_private_endpoints" {
  description = "Put ACR behind a private endpoint (requires acr_sku = Premium, which costs more)."
  type        = bool
  default     = false
}

variable "budget_amount" {
  description = "Monthly budget for the whole subscription, in your billing currency."
  type        = number
  default     = 20
}

variable "budget_contact_emails" {
  description = "Where budget alerts are sent. Set this in terraform.tfvars (not committed)."
  type        = list(string)
}

variable "owner" {
  description = "Value for the owner tag."
  type        = string
  default     = "kirthikesh"
}

variable "location" {
  description = "Azure region for the state storage account."
  type        = string
  default     = "northeurope" # Dublin
}

variable "location_short" {
  description = "Short region code used in resource names."
  type        = string
  default     = "neu"
}

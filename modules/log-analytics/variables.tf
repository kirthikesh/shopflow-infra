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

variable "retention_in_days" {
  type    = number
  default = 30
}

variable "daily_quota_gb" {
  description = "Ingestion cap per day in GB. -1 means no cap."
  type        = number
  default     = 0.5
}

variable "tags" {
  type    = map(string)
  default = {}
}

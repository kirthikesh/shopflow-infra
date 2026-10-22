variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "kubernetes_version" {
  description = "null = the current AKS default version."
  type        = string
  default     = null
}

variable "node_subnet_id" {
  type = string
}

variable "node_vm_size" {
  description = "2 vCPU / 8 GB is the smallest size that runs the whole ShopFlow stack comfortably."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "node_min_count" {
  type    = number
  default = 1
}

variable "node_max_count" {
  type    = number
  default = 2
}

variable "pod_cidr" {
  description = "Overlay range for pod IPs. Must not overlap any VNet."
  type        = string
  default     = "192.168.0.0/16"
}

variable "service_cidr" {
  description = "Range for Kubernetes service IPs. Must not overlap any VNet or the pod range."
  type        = string
  default     = "172.16.0.0/16"
}

variable "api_server_private" {
  description = "true = private cluster (no public API endpoint). Changing this recreates the cluster."
  type        = bool
  default     = false
}

variable "api_server_authorized_ip_ranges" {
  description = "CIDRs allowed to reach the public API server, e.g. [\"203.0.113.7/32\"]."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.api_server_authorized_ip_ranges : can(cidrhost(c, 0))])
    error_message = "Each entry must be a CIDR, for example 203.0.113.7/32."
  }
}

variable "acr_id" {
  type = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "admin_object_ids" {
  description = "Entra ID object IDs that administer this resource, keyed by role, e.g. { owner = \"...\", pipeline = \"...\" }."
  type        = map(string)
}

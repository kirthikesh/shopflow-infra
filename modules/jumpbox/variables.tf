variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "vm_size" {
  type = string
}

variable "admin_username" {
  type    = string
  default = "shopflow"
}

variable "ssh_public_key" {
  description = "Contents of your public key, e.g. ~/.ssh/id_ed25519.pub."
  type        = string

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256) ", var.ssh_public_key))
    error_message = "ssh_public_key must be the contents of a .pub file."
  }
}

variable "auto_shutdown_time" {
  description = "HHMM, Irish time."
  type        = string
  default     = "2200"
}

variable "tags" {
  type    = map(string)
  default = {}
}

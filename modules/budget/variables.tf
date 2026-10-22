variable "name_prefix" {
  type = string
}

variable "subscription_id" {
  description = "Full subscription resource ID, e.g. /subscriptions/<guid>."
  type        = string
}

variable "amount" {
  description = "Monthly budget in the subscription's billing currency."
  type        = number
}

variable "start_date" {
  description = "First day of the current month, RFC3339 (e.g. 2026-10-01T00:00:00Z)."
  type        = string
}

variable "contact_emails" {
  type = list(string)

  validation {
    condition     = length(var.contact_emails) > 0
    error_message = "Add at least one email address for budget alerts."
  }
}

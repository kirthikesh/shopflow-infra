# Monthly subscription budget with email alerts. This is the first safety net:
# Azure emails you at 50%, 80% and 100% of actual spend, and when the forecast
# says you'll go over. Budgets alert; they do not stop resources.

resource "azurerm_consumption_budget_subscription" "this" {
  name            = "budget-${var.name_prefix}-monthly"
  subscription_id = var.subscription_id
  amount          = var.amount
  time_grain      = "Monthly"

  time_period {
    start_date = var.start_date
  }

  dynamic "notification" {
    for_each = toset([50, 80, 100])
    content {
      enabled        = true
      threshold      = notification.value
      threshold_type = "Actual"
      operator       = "GreaterThanOrEqualTo"
      contact_emails = var.contact_emails
    }
  }

  notification {
    enabled        = true
    threshold      = 100
    threshold_type = "Forecasted"
    operator       = "GreaterThanOrEqualTo"
    contact_emails = var.contact_emails
  }

  lifecycle {
    # The start date only matters at creation; don't fight it every month.
    ignore_changes = [time_period]
  }
}

# Azure Service Bus for the order flow, matching the local emulator exactly:
#   queue  order-created        order-service -> payment-service
#   topic  payment-events       payment-service -> two subscriptions:
#            order-service        (updates the order status)
#            notification-service (sends the email)
# Standard tier: Basic has no topics.

resource "azurerm_servicebus_namespace" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  minimum_tls_version = "1.2"

  # Phase 3 apps connect with a connection string. Phase 7 moves them to
  # Workload Identity and this gets switched off.
  local_auth_enabled = true

  tags = var.tags
}

resource "azurerm_servicebus_queue" "order_created" {
  name         = "order-created"
  namespace_id = azurerm_servicebus_namespace.this.id

  max_delivery_count                      = 5
  lock_duration                           = "PT1M"
  default_message_ttl                     = "PT1H"
  dead_lettering_on_message_expiration    = true
  requires_duplicate_detection            = true
  duplicate_detection_history_time_window = "PT10M"
}

resource "azurerm_servicebus_topic" "payment_events" {
  name         = "payment-events"
  namespace_id = azurerm_servicebus_namespace.this.id

  default_message_ttl                     = "PT1H"
  requires_duplicate_detection            = true
  duplicate_detection_history_time_window = "PT10M"
}

resource "azurerm_servicebus_subscription" "this" {
  for_each = toset(["order-service", "notification-service"])

  name     = each.value
  topic_id = azurerm_servicebus_topic.payment_events.id

  max_delivery_count                   = 5
  lock_duration                        = "PT1M"
  default_message_ttl                  = "PT1H"
  dead_lettering_on_message_expiration = true
}

# Least privilege: the apps can send and listen, but not manage the namespace.
resource "azurerm_servicebus_namespace_authorization_rule" "app" {
  name         = "shopflow-app"
  namespace_id = azurerm_servicebus_namespace.this.id
  listen       = true
  send         = true
  manage       = false
}

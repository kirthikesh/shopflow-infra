# Private DNS zones so names like myregistry.azurecr.io resolve to private IPs
# inside the VNets. Zones live once in the hub; each VNet gets a link.

resource "azurerm_private_dns_zone" "this" {
  for_each = toset(var.zones)

  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

locals {
  # Every (zone, vnet) pair needs its own link.
  links = {
    for pair in setproduct(var.zones, keys(var.vnet_ids)) :
    "${pair[0]}|${pair[1]}" => { zone = pair[0], vnet_key = pair[1] }
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = local.links

  name                 = "link-${each.value.vnet_key}"
  private_dns_zone_id  = azurerm_private_dns_zone.this[each.value.zone].id
  virtual_network_id   = var.vnet_ids[each.value.vnet_key]
  registration_enabled = false
  tags                 = var.tags
}

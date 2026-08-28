resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${var.application_name}-${var.environment_name}-${var.vnet_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "assoc" {
  subnet_id                 = var.subnet_id
  network_security_group_id = azurerm_network_security_group.nsg.id
  depends_on                = [azurerm_network_security_rule.rules]
}

resource "azurerm_network_security_rule" "rules" {
  for_each = {
    for r in var.security_rules :
    r.name => r
  }

  name                        = each.value.name
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg.name
  protocol                    = each.value.protocol
  access                      = each.value.access
  priority                    = each.value.priority
  direction                   = each.value.direction
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix

  source_port_range  = length(split(",", each.value.source_port_range)) == 1 ? each.value.source_port_range : null
  source_port_ranges = length(split(",", each.value.source_port_range)) == 1 ? null : split(",", each.value.source_port_range)

  destination_port_range  = length(split(",", each.value.destination_port_range)) == 1 ? each.value.destination_port_range : null
  destination_port_ranges = length(split(",", each.value.destination_port_range)) == 1 ? null : split(",", each.value.destination_port_range)
}


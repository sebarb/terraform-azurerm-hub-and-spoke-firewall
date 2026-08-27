//Create user defined route - default route 0.0.0.0/0 for spoke subnets will be firewall applicance
resource "azurerm_route_table" "route_table" {
  name                = "udr-${var.application_name}-${var.environment_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_subnet_route_table_association" "route_table_assoc" {
  for_each       = var.subnet_ids
  route_table_id = azurerm_route_table.route_table.id
  subnet_id      = each.value

}


resource "azurerm_route" "default_route" {
  name                   = "route-${var.application_name}-${var.environment_name}-01"
  resource_group_name    = var.resource_group_name
  route_table_name       = azurerm_route_table.route_table.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.next_hop
}


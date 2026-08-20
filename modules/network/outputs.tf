
output "id" {
  value = azurerm_virtual_network.vnet.id
}

output "name" {
  value = azurerm_virtual_network.vnet.name
}

output "subnets" {
  value = {
    for k, v in azurerm_subnet.subnets :
    k => v
  }
}


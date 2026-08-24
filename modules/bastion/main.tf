resource "azurerm_public_ip" "public_ip_bastion" {
  name                = "ip-${var.application_name}-${var.environment_name}-bastion"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  allocation_method   = "Static"
}

resource "azurerm_bastion_host" "bastion" {
  name                = "bastion-${var.application_name}-${var.environment_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  ip_configuration {
    name                 = "ipconfig_bastion"
    subnet_id            = var.subnet_id
    public_ip_address_id = azurerm_public_ip.public_ip_bastion.id
  }
}

//Create VM in hub-1
resource "azurerm_network_interface" "nic" {
  name                = "nic-${var.application_name}-${var.environment_name}-${var.vm_scope}-${var.vm_number}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig-spoke01"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_linux_virtual_machine" "vm" {
  name                            = "vm-${var.application_name}-${var.environment_name}-${var.vm_scope}-${var.vm_number}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  size                            = "Standard_B1s"
  disable_password_authentication = false
  admin_username                  = "localadmin"
  admin_password                  = "Blablabla123!"
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]
  /*
  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }
*/
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  custom_data = var.file_config
}

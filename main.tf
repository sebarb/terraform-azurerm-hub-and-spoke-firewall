resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.application_name}-${var.environment_name}"
  location = var.location
}
locals {
  vnets = {
    vnet1 = {
      name  = "hub"
      space = "192.168.0.0/16"
    }
    vnet2 = {
      name  = "spoke-01"
      space = "10.1.0.0/16"
    }
    vnet3 = {
      name  = "spoke-02"
      space = "10.2.0.0/16"
    }
  }
}
resource "azurerm_virtual_network" "vnet" {
  for_each            = local.vnets
  name                = "vnet-${var.application_name}-${var.environment_name}-${each.value.name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [each.value.space]
}
//Create subnet-1 in each virtual network
resource "azurerm_subnet" "subnets" {
  for_each             = local.vnets
  name                 = "subnet-01"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet[each.key].name
  address_prefixes     = [cidrsubnet(each.value.space, 8, 1)]
}

//Create dedicated subnet for the firewall
resource "azurerm_subnet" "subnetfireall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet["vnet1"].name
  address_prefixes     = [cidrsubnet(local.vnets.vnet1.space, 10, 0)]
}
//Create peerings between hub and spokes
resource "azurerm_virtual_network_peering" "hub_spoke1" {
  name                      = "peering-hub-spoke1"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet["vnet1"].name
  remote_virtual_network_id = azurerm_virtual_network.vnet["vnet2"].id

}
resource "azurerm_virtual_network_peering" "spoke1_hub" {
  name                      = "peering-spoke1-hub"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet["vnet2"].name
  remote_virtual_network_id = azurerm_virtual_network.vnet["vnet1"].id
  allow_forwarded_traffic   = true
}
resource "azurerm_virtual_network_peering" "hub_spoke2" {
  name                      = "peering-hub-spoke2"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet["vnet1"].name
  remote_virtual_network_id = azurerm_virtual_network.vnet["vnet3"].id
}
resource "azurerm_virtual_network_peering" "spoke2_hub" {
  name                      = "peering-spoke2-hub"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet["vnet3"].name
  remote_virtual_network_id = azurerm_virtual_network.vnet["vnet1"].id
  allow_forwarded_traffic   = true
}
//Create tls ssh private key
resource "tls_private_key" "ssh_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

//Create VM in hub-1
resource "azurerm_network_interface" "nic_01" {
  name                = "nic-${var.application_name}-${var.environment_name}-spoke01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig-spoke01"
    subnet_id                     = azurerm_subnet.subnets["vnet2"].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm_01" {
  name                            = "vm-${var.application_name}-${var.environment_name}-spoke01"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = "Standard_B1s"
  disable_password_authentication = false
  admin_username                  = "localadmin"
  admin_password                  = var.password
  network_interface_ids = [
    azurerm_network_interface.nic_01.id,
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
  custom_data = base64encode(file("./webapp-config.yaml"))
}
//Create vm in subnet-2
resource "azurerm_network_interface" "nic_02" {
  name                = "nic-${var.application_name}-${var.environment_name}-spoke02"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig-spoke02"
    subnet_id                     = azurerm_subnet.subnets["vnet3"].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm_02" {
  name                            = "vm-${var.application_name}-${var.environment_name}-spoke02"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = "Standard_B1s"
  admin_username                  = "localadmin"
  admin_password                  = var.password
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.nic_02.id,
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
  custom_data = base64encode(file("./webapp-config.yaml"))
}
//Create public IP
resource "azurerm_public_ip" "public_ip" {
  name                = "publicip-${var.application_name}-${var.environment_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  zones               = [1]
}

//Azure firewall
resource "azurerm_firewall_policy" "firewall_policy" {
  name                = "fw-policy-${var.application_name}-${var.environment_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}


resource "azurerm_firewall" "azure_firewall" {
  name                = "firewall-${var.application_name}-${var.environment_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.firewall_policy.id
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.subnetfireall.id
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }
}
resource "azurerm_firewall_policy_rule_collection_group" "policy_group" {
  name               = "policy-group"
  firewall_policy_id = azurerm_firewall_policy.firewall_policy.id
  priority           = 200
  nat_rule_collection {
    name     = "nat-col1"
    priority = 200
    action   = "Dnat"
    rule {
      name                = "nat-spoke1"
      source_addresses    = ["*"]
      destination_address = azurerm_public_ip.public_ip.ip_address
      destination_ports   = ["8080"]
      translated_address  = azurerm_network_interface.nic_01.ip_configuration[0].private_ip_address
      translated_port     = "80"
      protocols           = ["TCP"]
    }
    rule {
      name                = "nat-spoke2"
      source_addresses    = ["*"]
      destination_address = azurerm_public_ip.public_ip.ip_address
      destination_ports   = ["8081"]
      translated_address  = azurerm_network_interface.nic_02.ip_configuration[0].private_ip_address
      translated_port     = "80"
      protocols           = ["TCP"]
    }
  }
  network_rule_collection {
    name     = "net-coll1"
    priority = 300
    action   = "Allow"
    rule {
      name                  = "vnet2-to-vnet3"
      source_addresses      = azurerm_subnet.subnets["vnet2"].address_prefixes
      destination_addresses = azurerm_subnet.subnets["vnet3"].address_prefixes
      destination_ports     = ["80"]
      protocols             = ["TCP"]
    }
    rule {
      name                  = "vnet3-to-vnet2"
      source_addresses      = azurerm_subnet.subnets["vnet3"].address_prefixes
      destination_addresses = azurerm_subnet.subnets["vnet2"].address_prefixes
      destination_ports     = ["80"]
      protocols             = ["TCP"]
    }
  }
}
//Create user defined route - default route 0.0.0.0/0 for spoke subnets will be firewall applicance
resource "azurerm_route_table" "route_table" {
  name                = "udr-${var.application_name}-${var.environment_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

}

resource "azurerm_subnet_route_table_association" "route_table_assoc-1" {
  route_table_id = azurerm_route_table.route_table.id
  subnet_id      = azurerm_subnet.subnets["vnet2"].id
}

resource "azurerm_subnet_route_table_association" "route_table_assoc-2" {
  route_table_id = azurerm_route_table.route_table.id
  subnet_id      = azurerm_subnet.subnets["vnet3"].id
}

resource "azurerm_route" "default_route" {
  name                   = "route-${var.application_name}-${var.environment_name}-01"
  resource_group_name    = azurerm_resource_group.rg.name
  route_table_name       = azurerm_route_table.route_table.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.azure_firewall.ip_configuration[0].private_ip_address
}

//Create resource group
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.application_name}-${var.environment_name}"
  location = var.location
}

//Define locals for vnets
locals {
  vnets = {
    vnet1 = {
      name  = "hub"
      space = "192.168.0.0/16"
      subnets = {
        firewall = {
          name   = "AzureFirewallSubnet"
          digits = 8
          netnum = 1
        }
        bastion = {
          name   = "AzureBastionSubnet"
          digits = 10
          netnum = 1
        }
      }
    }
    vnet2 = {
      name  = "spoke-01"
      space = "10.1.0.0/16"
      subnets = {
        default = {
          name   = "subnet-01"
          digits = 8
          netnum = 1
        }
      }
    }
    vnet3 = {
      name  = "spoke-02"
      space = "10.2.0.0/16"
      role  = "spoke"
      subnets = {
        default = {
          name   = "subnet-01"
          digits = 8
          netnum = 1
        }
      }
    }
  }
  common_tags = {
    application = var.application_name
    environment = var.environment_name
    managedby   = "terraform"
  }
}
//Create network infrastructure

module "vnet" {
  source              = "./modules/network"
  for_each            = local.vnets
  vnet_name           = each.value.name
  application_name    = var.application_name
  environment_name    = var.environment_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = each.value.space
  subnets             = each.value.subnets
  tags                = local.common_tags
}
//Creates the peerings between hub and spokes
//Perrings hub to spokes
resource "azurerm_virtual_network_peering" "hub_spokes" {
  for_each = {
    for k, v in local.vnets :
    k => v
    if k != "vnet1"
  }
  name                      = "hub_to_${each.value.name}"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = module.vnet["vnet1"].name
  remote_virtual_network_id = module.vnet[each.key].id
}

//Peering spokes to hub
resource "azurerm_virtual_network_peering" "spokes_to_hub" {
  for_each = {
    for k, v in local.vnets :
    k => v
    if k != "vnet1"
  }
  name                      = "hub_to_${each.value.name}"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = module.vnet[each.key].name
  remote_virtual_network_id = module.vnet["vnet1"].id
}


//Create tls ssh private key
resource "tls_private_key" "ssh_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

module "vm" {
  source = "./modules/compute"
  for_each = {
    for k, v in local.vnets :
    k => v
    if k != "vnet1"
  }
  application_name    = var.application_name
  environment_name    = var.environment_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  vm_scope            = "web"
  vm_number           = substr(each.value.name, 6, 2)
  subnet_id           = module.vnet[each.key].subnets["default"].id
  file_config         = filebase64("./webapp-config.yaml")
  public_key          = tls_private_key.ssh_private_key.public_key_openssh
  tags                = local.common_tags
}

//Create public IP
resource "azurerm_public_ip" "public_ip" {
  name                = "publicip-${var.application_name}-${var.environment_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  zones               = [1]
  tags                = local.common_tags
}

//Create firewall
module "firewall" {
  for_each = {
    for k, v in local.vnets :
    k => v
    if k == "vnet1"
  }
  source              = "./modules/firewall"
  application_name    = var.application_name
  environment_name    = var.environment_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  subnet_id           = module.vnet[each.key].subnets["firewall"].id
  public_ip_id        = azurerm_public_ip.public_ip.id
  public_ip_address   = azurerm_public_ip.public_ip.ip_address
  nat_rules = {
    spoke01 = {
      name                = "spoke1"
      destination_address = azurerm_public_ip.public_ip.ip_address
      destination_ports   = ["8080"]
      translated_port     = "80"
      translated_address  = module.vm["vnet2"].vm_ip
      protocols           = ["TCP"]
      source_addresses    = ["*"]
    }
    spoke02 = {
      name                = "spoke2"
      destination_address = azurerm_public_ip.public_ip.ip_address
      destination_ports   = ["8081"]
      translated_port     = "80"
      translated_address  = module.vm["vnet3"].vm_ip
      protocols           = ["TCP"]
      source_addresses    = ["*"]
    }
  }
  network_rules = {
    rule1 = {
      source_addresses      = module.vnet["vnet2"].subnets["default"].address_prefixes
      destination_addresses = module.vnet["vnet3"].subnets["default"].address_prefixes
      destination_ports     = ["80"]
      protocols             = ["TCP"]
    }
    rule2 = {
      source_addresses      = module.vnet["vnet3"].subnets["default"].address_prefixes
      destination_addresses = module.vnet["vnet2"].subnets["default"].address_prefixes
      destination_ports     = ["80"]
      protocols             = ["TCP"]
    }
  }
  tags = local.common_tags
}

//Create routing table
module "routing" {
  source              = "./modules/routing"
  application_name    = var.application_name
  environment_name    = var.environment_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  next_hop            = module.firewall["vnet1"].firewall_ip[0].private_ip_address
  subnet_ids = {
    for k, v in local.vnets :
    k => module.vnet[k].subnets["default"].id
    if k != "vnet1"
  }
  tags = local.common_tags
}

//Create bastion
module "bastion" {
  source              = "./modules/bastion"
  application_name    = var.application_name
  environment_name    = var.environment_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_public_ip.public_ip.location
  subnet_id           = module.vnet["vnet1"].subnets["bastion"].id
  tags                = local.common_tags
}

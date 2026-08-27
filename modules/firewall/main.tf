//Azure firewall
resource "azurerm_firewall_policy" "firewall_policy" {
  name                = "fw-policy-${var.application_name}-${var.environment_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}



resource "azurerm_firewall" "azure_firewall" {
  name                = "firewall-${var.application_name}-${var.environment_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.firewall_policy.id
  ip_configuration {
    name                 = "configuration"
    subnet_id            = var.subnet_id
    public_ip_address_id = var.public_ip_id
  }
  tags = var.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "policy_group" {
  name               = "policy-group"
  firewall_policy_id = azurerm_firewall_policy.firewall_policy.id
  priority           = 200
  nat_rule_collection {
    name     = "nat-col1"
    priority = 200
    action   = "Dnat"
    dynamic "rule" {
      for_each = var.nat_rules
      content {
        name                = rule.key
        source_addresses    = rule.value.source_addresses
        destination_address = var.public_ip_address
        destination_ports   = rule.value.destination_ports
        translated_port     = rule.value.translated_port
        translated_address  = rule.value.translated_address
        protocols           = rule.value.protocols
      }
    }
  }
  network_rule_collection {
    name     = "net-coll1"
    priority = "300"
    action   = "Allow"
    dynamic "rule" {
      for_each = var.network_rules
      content {
        name                  = rule.key
        source_addresses      = rule.value.source_addresses
        destination_addresses = rule.value.destination_addresses
        destination_ports     = rule.value.destination_ports
        protocols             = rule.value.protocols
      }
    }
  }
}

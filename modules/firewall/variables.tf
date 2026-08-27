variable "application_name" {
  type = string
}
variable "environment_name" {
  type = string
}
variable "resource_group_name" {
  type = string
}
variable "location" {
  type = string
}
variable "subnet_id" {
  type = string
}
variable "public_ip_id" {
  type = string
}

variable "public_ip_address" {
  type = string
}

variable "nat_rules" {
  type = map(object({
    source_addresses    = list(string)
    destination_address = string
    destination_ports   = list(string)
    translated_address  = string
    translated_port     = string
    protocols           = list(string)
  }))
  default = {}
}

variable "network_rules" {
  type = map(object({
    source_addresses      = list(string)
    destination_addresses = list(string)
    destination_ports     = list(string)
    protocols             = list(string)
  }))
  default = {}
}
variable "tags" {
  type    = map(string)
  default = {}
}

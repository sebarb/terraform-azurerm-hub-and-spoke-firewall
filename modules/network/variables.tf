variable "application_name" {
  type = string
}
variable "environment_name" {
  type = string
}
variable "location" {
  type = string
}
variable "resource_group_name" {
  type = string
}

variable "vnet_name" {
  type = string
}
variable "address_space" {
  type = string
}
variable "subnets" {
  type = map(object({
    name   = string
    digits = number
    netnum = number
  }))
}

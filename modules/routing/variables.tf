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
variable "next_hop" {
  type = string
}
variable "subnet_ids" {
  type = map(string)
}

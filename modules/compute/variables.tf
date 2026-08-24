variable "application_name" {
  type = string
}
variable "environment_name" {
  type = string
}
variable "location" {
  type = string
}
variable "vm_scope" {
  type = string
}
variable "vm_number" {
  type = string
}
variable "resource_group_name" {
  type = string
}
variable "file_config" {
  type = string
}
variable "subnet_id" {
  type = string
}
variable "public_key" {
  type      = string
  sensitive = true
}

variable "resource_group_name" {
  description = "Resource group where network resources are created."
  type        = string
}

variable "location" {
  description = "Azure region for network resources."
  type        = string
}

variable "vnet_name" {
  description = "Virtual network name."
  type        = string
}

variable "vnet_address_space" {
  description = "Virtual network CIDR ranges."
  type        = list(string)
}

variable "subnet_name" {
  description = "AKS subnet name."
  type        = string
}

variable "subnet_address_prefixes" {
  description = "AKS subnet CIDR ranges."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to network resources."
  type        = map(string)
  default     = {}
}

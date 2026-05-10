variable "name" {
  description = "ACR name. Must be globally unique and alphanumeric."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for ACR."
  type        = string
}

variable "location" {
  description = "Azure region for ACR."
  type        = string
}

variable "sku" {
  description = "ACR SKU tier."
  type        = string
  default     = "Basic"
}

variable "tags" {
  description = "Tags applied to ACR."
  type        = map(string)
  default     = {}
}

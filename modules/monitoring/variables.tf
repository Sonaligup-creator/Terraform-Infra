variable "name" {
  description = "Log Analytics workspace name."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for Log Analytics."
  type        = string
}

variable "location" {
  description = "Azure region for Log Analytics."
  type        = string
}

variable "retention_in_days" {
  description = "Log retention period in days."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to Log Analytics workspace."
  type        = map(string)
  default     = {}
}

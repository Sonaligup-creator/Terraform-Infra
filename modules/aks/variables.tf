variable "name" {
  description = "AKS cluster name."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group where AKS is created."
  type        = string
}

variable "location" {
  description = "Azure region for AKS."
  type        = string
}

variable "dns_prefix" {
  description = "AKS DNS prefix."
  type        = string
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version. Null uses default regional version."
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Subnet ID for AKS nodes."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Optional Log Analytics workspace ID for Container Insights."
  type        = string
  default     = null
}

variable "system_node_vm_size" {
  description = "VM size for system node pool."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "system_node_min_count" {
  description = "Minimum node count for system pool."
  type        = number
  default     = 1
}

variable "system_node_max_count" {
  description = "Maximum node count for system pool."
  type        = number
  default     = 3
}

variable "system_node_os_disk_size_gb" {
  description = "OS disk size for system node pool."
  type        = number
  default     = 128
}

variable "system_node_max_pods" {
  description = "Maximum pods per node for system pool."
  type        = number
  default     = 30
}

variable "enable_user_node_pool" {
  description = "Whether to create a user node pool."
  type        = bool
  default     = true
}

variable "user_node_vm_size" {
  description = "VM size for user node pool."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "user_node_min_count" {
  description = "Minimum node count for user pool."
  type        = number
  default     = 1
}

variable "user_node_max_count" {
  description = "Maximum node count for user pool."
  type        = number
  default     = 5
}

variable "user_node_os_disk_size_gb" {
  description = "OS disk size for user node pool."
  type        = number
  default     = 128
}

variable "user_node_max_pods" {
  description = "Maximum pods per node for user pool."
  type        = number
  default     = 30
}

variable "zones" {
  description = "Availability zones for node pools."
  type        = list(string)
  default     = []
}

variable "sku_tier" {
  description = "AKS tier. Use Free for development and Standard for production."
  type        = string
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard"], var.sku_tier)
    error_message = "sku_tier must be Free or Standard."
  }
}

variable "tags" {
  description = "Tags applied to AKS resources."
  type        = map(string)
  default     = {}
}

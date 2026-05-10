variable "project_name" {
  description = "Project slug used in resource naming."
  type        = string
  default     = "microservices"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name can contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "environment must be one of dev, stage, or prod."
  }
}

variable "location" {
  description = "Azure region. Restricted by policy to approved values."
  type        = string
  default     = "centralindia"

  validation {
    condition = contains([
      "malaysiawest",
      "southeastasia",
      "uaenorth",
      "centralindia",
      "koreacentral"
    ], var.location)
    error_message = "location must be one of: malaysiawest, southeastasia, uaenorth, centralindia, koreacentral."
  }
}

variable "common_tags" {
  description = "Additional tags merged with standard tags."
  type        = map(string)
  default     = {}
}

variable "kubernetes_version" {
  description = "Pinned AKS version. Null uses the default supported version in region."
  type        = string
  default     = null
}

variable "acr_sku" {
  description = "Container Registry SKU."
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "acr_sku must be Basic, Standard, or Premium."
  }
}

variable "sku_tier" {
  description = "AKS tier."
  type        = string
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard"], var.sku_tier)
    error_message = "sku_tier must be Free or Standard."
  }
}

variable "vnet_address_space" {
  description = "VNet CIDR blocks."
  type        = list(string)
  default     = ["10.40.0.0/16"]
}

variable "aks_subnet_prefixes" {
  description = "AKS subnet CIDR blocks."
  type        = list(string)
  default     = ["10.40.1.0/24"]
}

variable "system_node_vm_size" {
  description = "System node pool VM SKU."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "system_node_min_count" {
  description = "Minimum autoscale node count for system pool."
  type        = number
  default     = 1
}

variable "system_node_max_count" {
  description = "Maximum autoscale node count for system pool."
  type        = number
  default     = 3
}

variable "system_node_os_disk_size_gb" {
  description = "System node pool OS disk size."
  type        = number
  default     = 128
}

variable "system_node_max_pods" {
  description = "Maximum pods per system node."
  type        = number
  default     = 30
}

variable "enable_user_node_pool" {
  description = "Whether to create a user node pool."
  type        = bool
  default     = true
}

variable "user_node_vm_size" {
  description = "User node pool VM SKU."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "user_node_min_count" {
  description = "Minimum autoscale node count for user pool."
  type        = number
  default     = 1
}

variable "user_node_max_count" {
  description = "Maximum autoscale node count for user pool."
  type        = number
  default     = 5
}

variable "user_node_os_disk_size_gb" {
  description = "User node pool OS disk size."
  type        = number
  default     = 128
}

variable "user_node_max_pods" {
  description = "Maximum pods per user node."
  type        = number
  default     = 30
}

variable "zones" {
  description = "Availability zones for node pools. Empty list disables zones."
  type        = list(string)
  default     = []
}

variable "log_analytics_retention_days" {
  description = "Retention period for Log Analytics workspace."
  type        = number
  default     = 30
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

locals {
  location_short_map = {
    malaysiawest = "myw"
    southeastasia = "sea"
    uaenorth      = "uan"
    centralindia  = "cin"
    koreacentral  = "krc"
  }

  location_short = lookup(local.location_short_map, var.location, "glb")
  name_prefix    = lower("${var.project_name}-${var.environment}-${local.location_short}-${random_string.suffix.result}")

  acr_name = substr(replace(lower("${var.project_name}${var.environment}${local.location_short}${random_string.suffix.result}"), "-", ""), 0, 50)

  tags = merge({
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
  }, var.common_tags)
}

module "resource_group" {
  source   = "../../modules/resource_group"
  name     = substr("rg-${local.name_prefix}", 0, 90)
  location = var.location
  tags     = local.tags
}

module "network" {
  source                  = "../../modules/network"
  resource_group_name     = module.resource_group.name
  location                = module.resource_group.location
  vnet_name               = substr("vnet-${local.name_prefix}", 0, 64)
  vnet_address_space      = var.vnet_address_space
  subnet_name             = "snet-aks"
  subnet_address_prefixes = var.aks_subnet_prefixes
  tags                    = local.tags
}

module "acr" {
  source              = "../../modules/acr"
  name                = local.acr_name
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  sku                 = var.acr_sku
  tags                = local.tags
}

module "monitoring" {
  source              = "../../modules/monitoring"
  name                = substr("law-${local.name_prefix}", 0, 63)
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  retention_in_days   = var.log_analytics_retention_days
  tags                = local.tags
}

module "aks" {
  source                     = "../../modules/aks"
  name                       = substr("aks-${local.name_prefix}", 0, 63)
  resource_group_name        = module.resource_group.name
  location                   = module.resource_group.location
  dns_prefix                 = substr("dns-${local.name_prefix}", 0, 54)
  kubernetes_version         = var.kubernetes_version
  subnet_id                  = module.network.subnet_id
  log_analytics_workspace_id = module.monitoring.id
  system_node_vm_size        = var.system_node_vm_size
  system_node_min_count      = var.system_node_min_count
  system_node_max_count      = var.system_node_max_count
  system_node_os_disk_size_gb = var.system_node_os_disk_size_gb
  system_node_max_pods       = var.system_node_max_pods
  enable_user_node_pool      = var.enable_user_node_pool
  user_node_vm_size          = var.user_node_vm_size
  user_node_min_count        = var.user_node_min_count
  user_node_max_count        = var.user_node_max_count
  user_node_os_disk_size_gb  = var.user_node_os_disk_size_gb
  user_node_max_pods         = var.user_node_max_pods
  zones                      = var.zones
  sku_tier                   = var.sku_tier
  tags                       = local.tags
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = module.acr.id
  role_definition_name             = "AcrPull"
  principal_id                     = module.aks.kubelet_identity_object_id
  skip_service_principal_aad_check = true
}

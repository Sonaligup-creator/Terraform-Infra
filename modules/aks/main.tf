resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_node_vm_size
    type                         = "VirtualMachineScaleSets"
    enable_auto_scaling          = true
    min_count                    = var.system_node_min_count
    max_count                    = var.system_node_max_count
    os_disk_size_gb              = var.system_node_os_disk_size_gb
    max_pods                     = var.system_node_max_pods
    vnet_subnet_id               = var.subnet_id
    only_critical_addons_enabled = true
    zones                        = var.zones

    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  role_based_access_control_enabled = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  azure_policy_enabled              = true

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
  }

  dynamic "oms_agent" {
    for_each = var.log_analytics_workspace_id == null ? [] : [1]
    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  tags = var.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  count                 = var.enable_user_node_pool ? 1 : 0
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.user_node_vm_size
  mode                  = "User"
  os_type               = "Linux"
  enable_auto_scaling   = true
  min_count             = var.user_node_min_count
  max_count             = var.user_node_max_count
  os_disk_size_gb       = var.user_node_os_disk_size_gb
  max_pods              = var.user_node_max_pods
  vnet_subnet_id        = var.subnet_id
  zones                 = var.zones
  tags                  = var.tags
}

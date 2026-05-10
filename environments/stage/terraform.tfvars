project_name = "microservices"
environment  = "stage"
location     = "southeastasia"

acr_sku  = "Standard"
sku_tier = "Standard"

vnet_address_space = ["10.50.0.0/16"]
aks_subnet_prefixes = ["10.50.1.0/24"]

system_node_vm_size   = "Standard_D2s_v3"
system_node_min_count = 1
system_node_max_count = 3

enable_user_node_pool = true
user_node_vm_size     = "Standard_D2s_v3"
user_node_min_count   = 1
user_node_max_count   = 3

log_analytics_retention_days = 30

common_tags = {
  owner   = "sonali"
  purpose = "portfolio"
}

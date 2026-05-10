project_name = "microservices"
environment  = "prod"
location     = "uaenorth"

acr_sku  = "Standard"
sku_tier = "Standard"

vnet_address_space = ["10.60.0.0/16"]
aks_subnet_prefixes = ["10.60.1.0/24"]

system_node_vm_size   = "Standard_D2s_v3"
system_node_min_count = 2
system_node_max_count = 5

enable_user_node_pool = true
user_node_vm_size     = "Standard_D2s_v3"
user_node_min_count   = 2
user_node_max_count   = 6

log_analytics_retention_days = 60

common_tags = {
  owner   = "sonali"
  purpose = "portfolio"
}

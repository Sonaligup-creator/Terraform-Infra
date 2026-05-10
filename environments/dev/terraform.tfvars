project_name = "microservices"
environment  = "dev"
location     = "centralindia"

acr_sku  = "Basic"
sku_tier = "Free"

vnet_address_space = ["10.40.0.0/16"]
aks_subnet_prefixes = ["10.40.1.0/24"]

system_node_vm_size   = "Standard_D2s_v3"
system_node_min_count = 1
system_node_max_count = 2

enable_user_node_pool = true
user_node_vm_size     = "Standard_B2s_v2"
user_node_min_count   = 2
user_node_max_count   = 2

log_analytics_retention_days = 30

common_tags = {
  owner   = "sonali"
  purpose = "portfolio"
}

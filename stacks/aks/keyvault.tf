# Azure Key Vault for storing sensitive app secrets (MongoDB Atlas connection, JWT keys, etc.)

resource "azurerm_key_vault" "app_secrets" {
  name                        = substr("kv-${replace(local.name_prefix, "-", "")}", 0, 24)
  location                    = module.resource_group.location
  resource_group_name         = module.resource_group.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Backup",
      "Delete",
      "Get",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Set",
    ]
  }

  # Grant AKS managed identity read access to secrets
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = module.aks.kubelet_identity_object_id

    secret_permissions = [
      "Get",
      "List",
    ]
  }

  tags = local.tags
}

# Store MongoDB Atlas connection string
resource "azurerm_key_vault_secret" "mongo_uri" {
  count           = var.mongodb_atlas_connection_string != "" ? 1 : 0
  name            = "mongo-connection-string"
  value           = var.mongodb_atlas_connection_string
  key_vault_id    = azurerm_key_vault.app_secrets.id
  content_type    = "text/plain"
  expiration_date = null

  tags = local.tags
}

# Store JWT key
resource "azurerm_key_vault_secret" "jwt_key" {
  count           = var.jwt_key != "" ? 1 : 0
  name            = "jwt-key"
  value           = var.jwt_key
  key_vault_id    = azurerm_key_vault.app_secrets.id
  content_type    = "text/plain"
  expiration_date = null

  tags = local.tags
}

# Data source to get current Azure context (tenant ID, subscription ID, object ID)
data "azurerm_client_config" "current" {}

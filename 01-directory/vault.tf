# ==============================================================================
# File: vault.tf
# ==============================================================================
# Purpose:
#   - Create an Azure Key Vault for AD-related secrets.
#   - Ensure global name uniqueness using a random suffix.
#   - Grant current Terraform identity permission to manage secrets.
#
# Notes:
#   - Key Vault names must be globally unique.
#   - purge_protection_enabled = false is lab-friendly, not prod-safe.
#   - rbac_authorization_enabled = true uses Azure RBAC, not access policies.
# ==============================================================================

# ------------------------------------------------------------------------------
# Random suffix for Key Vault name
# Ensures global uniqueness across Azure.
# ------------------------------------------------------------------------------
resource "random_string" "key_vault_suffix" {
  length  = 8     # 8-character random suffix
  special = false # Only alphanumeric
  upper   = false # Lowercase only
}

# ------------------------------------------------------------------------------
# Key Vault resource
# ------------------------------------------------------------------------------
resource "azurerm_key_vault" "ad_key_vault" {
  name                       = "ad-key-vault-${random_string.key_vault_suffix.result}"
  resource_group_name        = azurerm_resource_group.ad.name
  location                   = azurerm_resource_group.ad.location
  sku_name                   = "standard"
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled   = false
  rbac_authorization_enabled = true
}

# ------------------------------------------------------------------------------
# Role assignment for current Terraform identity
# Grants permission to read/write/delete secrets in this Key Vault.
# ------------------------------------------------------------------------------
resource "azurerm_role_assignment" "kv_role_assignment" {
  scope                = azurerm_key_vault.ad_key_vault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

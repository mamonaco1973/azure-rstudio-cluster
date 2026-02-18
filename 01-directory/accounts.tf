# ==============================================================================
# File: accounts.tf
# ------------------------------------------------------------------------------
# Purpose:
#   - Generate strong random passwords for AD users.
#   - Store credentials as JSON secrets in Azure Key Vault.
#
# Notes:
#   - Each user receives a unique 24-character password.
#   - override_special restricts special chars for AD compatibility.
#   - Secrets depend on Key Vault RBAC assignment.
# ==============================================================================

# ------------------------------------------------------------------------------
# User: John Smith (jsmith)
# Generates password and stores AD credentials in Key Vault.
# ------------------------------------------------------------------------------

resource "random_password" "jsmith_password" {
  length           = 24     # 24-character secure password
  special          = true   # Include special characters
  override_special = "!@#%" # AD-compatible special characters
}

resource "azurerm_key_vault_secret" "jsmith_secret" {
  name         = "jsmith-ad-credentials" # Secret name in Key Vault
  key_vault_id = azurerm_key_vault.ad_key_vault.id
  depends_on   = [azurerm_role_assignment.kv_role_assignment]
  content_type = "application/json"

  value = jsonencode({
    username = "jsmith@${var.dns_zone}"
    password = random_password.jsmith_password.result
  })
}

# ------------------------------------------------------------------------------
# User: Emily Davis (edavis)
# ------------------------------------------------------------------------------

resource "random_password" "edavis_password" {
  length           = 24
  special          = true
  override_special = "!@#%"
}

resource "azurerm_key_vault_secret" "edavis_secret" {
  name         = "edavis-ad-credentials"
  key_vault_id = azurerm_key_vault.ad_key_vault.id
  depends_on   = [azurerm_role_assignment.kv_role_assignment]
  content_type = "application/json"

  value = jsonencode({
    username = "edavis@${var.dns_zone}"
    password = random_password.edavis_password.result
  })
}

# ------------------------------------------------------------------------------
# User: Raj Patel (rpatel)
# ------------------------------------------------------------------------------

resource "random_password" "rpatel_password" {
  length           = 24
  special          = true
  override_special = "!@#%"
}

resource "azurerm_key_vault_secret" "rpatel_secret" {
  name         = "rpatel-ad-credentials"
  key_vault_id = azurerm_key_vault.ad_key_vault.id
  depends_on   = [azurerm_role_assignment.kv_role_assignment]
  content_type = "application/json"

  value = jsonencode({
    username = "rpatel@${var.dns_zone}"
    password = random_password.rpatel_password.result
  })
}

# ------------------------------------------------------------------------------
# User: Amit Kumar (akumar)
# ------------------------------------------------------------------------------

resource "random_password" "akumar_password" {
  length           = 24
  special          = true
  override_special = "!@#%"
}

resource "azurerm_key_vault_secret" "akumar_secret" {
  name         = "akumar-ad-credentials"
  key_vault_id = azurerm_key_vault.ad_key_vault.id
  depends_on   = [azurerm_role_assignment.kv_role_assignment]
  content_type = "application/json"

  value = jsonencode({
    username = "akumar@${var.dns_zone}"
    password = random_password.akumar_password.result
  })
}

# ------------------------------------------------------------------------------
# User: sysadmin
# Local automation account (non-domain).
# ------------------------------------------------------------------------------

resource "random_password" "sysadmin_password" {
  length           = 24
  special          = true
  override_special = "!@#%"
}

resource "azurerm_key_vault_secret" "sysadmin_secret" {
  name         = "sysadmin-credentials"
  key_vault_id = azurerm_key_vault.ad_key_vault.id
  depends_on   = [azurerm_role_assignment.kv_role_assignment]
  content_type = "application/json"

  value = jsonencode({
    username = "sysadmin"
    password = random_password.sysadmin_password.result
  })
}

# ------------------------------------------------------------------------------
# User: Admin
# AD domain administrator account.
# ------------------------------------------------------------------------------

resource "random_password" "admin_password" {
  length           = 24
  special          = true
  override_special = "-_" # Alternate AD-compatible characters
}

resource "azurerm_key_vault_secret" "admin_secret" {
  name         = "admin-ad-credentials"
  key_vault_id = azurerm_key_vault.ad_key_vault.id
  depends_on   = [azurerm_role_assignment.kv_role_assignment]
  content_type = "application/json"

  value = jsonencode({
    username = "Admin@${var.dns_zone}"
    password = random_password.admin_password.result
  })
}

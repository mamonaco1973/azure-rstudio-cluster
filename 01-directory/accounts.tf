# ==============================================================================
# File: accounts.tf
# ------------------------------------------------------------------------------
# Purpose:
#   - Generate strong random passwords for AD users.
#   - Store credentials as JSON secrets in Azure Key Vault.
#
# Notes:
#   - Each user receives a unique 24-character password (23 random + "A" prefix).
#   - override_special restricts special chars to avoid shell interpolation issues.
#   - Secrets depend on Key Vault RBAC assignment.
# ==============================================================================

# ==============================================================================
# Password Resources
# ==============================================================================

resource "random_password" "jsmith_password" {
  length           = 23
  special          = true
  override_special = "-_"
  min_special      = 1
}

resource "random_password" "edavis_password" {
  length           = 23
  special          = true
  override_special = "-_"
  min_special      = 1
}

resource "random_password" "rpatel_password" {
  length           = 23
  special          = true
  override_special = "-_"
  min_special      = 1
}

resource "random_password" "akumar_password" {
  length           = 23
  special          = true
  override_special = "-_"
  min_special      = 1
}

resource "random_password" "sysadmin_password" {
  length           = 23
  special          = true
  override_special = "-_"
  min_special      = 1
}

resource "random_password" "admin_password" {
  length           = 23
  special          = true
  override_special = "-_"
  min_special      = 1
}

# ==============================================================================
# Safe Password Locals
# Prepend "A" so the first character is always a known-safe uppercase letter.
# Guarantees no password starts with "-" and satisfies AD complexity requirements.
# Reference local.* everywhere passwords are used — never raw random_password.result.
# ==============================================================================

locals {
  jsmith_password   = "A${random_password.jsmith_password.result}"
  edavis_password   = "A${random_password.edavis_password.result}"
  rpatel_password   = "A${random_password.rpatel_password.result}"
  akumar_password   = "A${random_password.akumar_password.result}"
  sysadmin_password = "A${random_password.sysadmin_password.result}"
  admin_password    = "A${random_password.admin_password.result}"
}

# ==============================================================================
# Key Vault Secrets
# ==============================================================================

resource "azurerm_key_vault_secret" "jsmith_secret" {
  name         = "jsmith-ad-credentials"
  key_vault_id = azurerm_key_vault.ad_key_vault.id
  depends_on   = [azurerm_role_assignment.kv_role_assignment]
  content_type = "application/json"

  value = jsonencode({
    username = "jsmith@${var.dns_zone}"
    password = local.jsmith_password
  })
}

resource "azurerm_key_vault_secret" "edavis_secret" {
  name         = "edavis-ad-credentials"
  key_vault_id = azurerm_key_vault.ad_key_vault.id
  depends_on   = [azurerm_role_assignment.kv_role_assignment]
  content_type = "application/json"

  value = jsonencode({
    username = "edavis@${var.dns_zone}"
    password = local.edavis_password
  })
}

resource "azurerm_key_vault_secret" "rpatel_secret" {
  name         = "rpatel-ad-credentials"
  key_vault_id = azurerm_key_vault.ad_key_vault.id
  depends_on   = [azurerm_role_assignment.kv_role_assignment]
  content_type = "application/json"

  value = jsonencode({
    username = "rpatel@${var.dns_zone}"
    password = local.rpatel_password
  })
}

resource "azurerm_key_vault_secret" "akumar_secret" {
  name         = "akumar-ad-credentials"
  key_vault_id = azurerm_key_vault.ad_key_vault.id
  depends_on   = [azurerm_role_assignment.kv_role_assignment]
  content_type = "application/json"

  value = jsonencode({
    username = "akumar@${var.dns_zone}"
    password = local.akumar_password
  })
}

resource "azurerm_key_vault_secret" "sysadmin_secret" {
  name         = "sysadmin-credentials"
  key_vault_id = azurerm_key_vault.ad_key_vault.id
  depends_on   = [azurerm_role_assignment.kv_role_assignment]
  content_type = "application/json"

  value = jsonencode({
    username = "sysadmin"
    password = local.sysadmin_password
  })
}

resource "azurerm_key_vault_secret" "admin_secret" {
  name         = "admin-ad-credentials"
  key_vault_id = azurerm_key_vault.ad_key_vault.id
  depends_on   = [azurerm_role_assignment.kv_role_assignment]
  content_type = "application/json"

  value = jsonencode({
    username = "Admin@${var.dns_zone}"
    password = local.admin_password
  })
}

# ==============================================================================
# File: storage.tf
# ==============================================================================
# Purpose:
#   - Create storage account for deployment scripts.
#   - Store rendered AD join script in private blob container.
#   - Generate short-lived SAS token for secure bootstrap access.
#
# Notes:
#   - Storage account name must be globally unique.
#   - Container access is private; SAS grants temporary read.
#   - SAS start time is backdated to reduce clock-skew failures.
# ==============================================================================

# ------------------------------------------------------------------------------
# Random Storage Name Suffix
# ------------------------------------------------------------------------------
# Generates lowercase alphanumeric suffix for global uniqueness.
# ------------------------------------------------------------------------------
resource "random_string" "storage_name" {
  length  = 10
  upper   = false
  special = false
  numeric = true
}

# ------------------------------------------------------------------------------
# Storage Account
# ------------------------------------------------------------------------------
# Standard/LRS is cost-effective and sufficient for script hosting.
# ------------------------------------------------------------------------------
resource "azurerm_storage_account" "scripts_storage" {
  name                     = "vmscripts${random_string.storage_name.result}"
  resource_group_name      = data.azurerm_resource_group.servers.name
  location                 = data.azurerm_resource_group.servers.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# ------------------------------------------------------------------------------
# Private Container
# ------------------------------------------------------------------------------
# No anonymous access; scripts accessible only via SAS token.
# ------------------------------------------------------------------------------
resource "azurerm_storage_container" "scripts" {
  name                  = "scripts"
  storage_account_id    = azurerm_storage_account.scripts_storage.id
  container_access_type = "private"
}

# ------------------------------------------------------------------------------
# Render AD Join Script
# ------------------------------------------------------------------------------
# Injects:
#   - Key Vault name
#   - Domain FQDN
#   - NFS gateway private IP
# ------------------------------------------------------------------------------
locals {
  ad_join_script = templatefile("./scripts/ad_join.ps1.template", {
    vault_name  = data.azurerm_key_vault.ad_key_vault.name
    domain_fqdn = var.dns_zone
    nfs_gateway = azurerm_network_interface.nfs_gateway_nic.ip_configuration[0].private_ip_address
  })
}

# ------------------------------------------------------------------------------
# Write Rendered Script Locally
# ------------------------------------------------------------------------------
resource "local_file" "ad_join_rendered" {
  filename = "./scripts/ad_join.ps1"
  content  = local.ad_join_script
}

# ------------------------------------------------------------------------------
# Upload Script as Blob
# ------------------------------------------------------------------------------
# Block blob is appropriate for discrete script files.
# Uncomment metadata block to force re-upload on every apply.
# ------------------------------------------------------------------------------
resource "azurerm_storage_blob" "ad_join_script" {
  name                   = "ad-join.ps1"
  storage_account_name   = azurerm_storage_account.scripts_storage.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  source                 = local_file.ad_join_rendered.filename

  #metadata = {
  #  force_update = "${timestamp()}" # Forces re-upload on each apply
  #}
}

# ------------------------------------------------------------------------------
# SAS Token (Read-Only, Short-Lived)
# ------------------------------------------------------------------------------
# Valid from 24h in the past to 72h in the future.
# ------------------------------------------------------------------------------
data "azurerm_storage_account_sas" "script_sas" {
  connection_string = azurerm_storage_account.scripts_storage.primary_connection_string

  resource_types {
    service   = false
    container = false
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  start  =    formatdate("YYYY-MM-DD'T'HH:mm:ss'Z'",
      timeadd(timestamp(), "-24h"))
  expiry =    formatdate("YYYY-MM-DD'T'HH:mm:ss'Z'",
      timeadd(timestamp(), "72h"))

  permissions {
    read    = true
    write   = false
    delete  = false
    list    = false
    add     = false
    create  = false
    update  = false
    process = false
    filter  = false
    tag     = false
  }
}

# ==============================================================================
# File: main.tf
# ==============================================================================
# Purpose:
#   - Configure AzureRM provider behavior for this deployment.
#   - Retrieve subscription and authenticated client context.
#   - Reference existing resource groups, network, subnet, and Key Vault.
#
# Notes:
#   - This module assumes core infrastructure already exists.
#   - All resources referenced here are data sources, not created.
# ==============================================================================

# ------------------------------------------------------------------------------
# AzureRM Provider
# Configures provider-level behavior for Key Vault lifecycle handling.
# ------------------------------------------------------------------------------
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = false
    }
  }
}

# ------------------------------------------------------------------------------
# Subscription Context
# Retrieves subscription metadata for the authenticated account.
# ------------------------------------------------------------------------------
data "azurerm_subscription" "primary" {}

# ------------------------------------------------------------------------------
# Client Context
# Retrieves tenant ID, object ID, and subscription for current identity.
# ------------------------------------------------------------------------------
data "azurerm_client_config" "current" {}

# ------------------------------------------------------------------------------
# Resource Groups
# References existing resource groups for networking and servers.
# ------------------------------------------------------------------------------
data "azurerm_resource_group" "ad" {
  name = var.network_group_name
}

data "azurerm_resource_group" "servers" {
  name = var.servers_group_name
}

# ------------------------------------------------------------------------------
# Virtual Network
# References the existing AD virtual network.
# ------------------------------------------------------------------------------
data "azurerm_virtual_network" "ad_vnet" {
  name                = "ad-vnet"
  resource_group_name = data.azurerm_resource_group.ad.name
}

# ------------------------------------------------------------------------------
# Subnet
# References the VM subnet within the AD virtual network.
# ------------------------------------------------------------------------------
data "azurerm_subnet" "vm_subnet" {
  name                 = "vm-subnet"
  resource_group_name  = data.azurerm_resource_group.ad.name
  virtual_network_name = data.azurerm_virtual_network.ad_vnet.name
}

# ------------------------------------------------------------------------------
# Key Vault
# References the existing Key Vault used for credential storage.
# ------------------------------------------------------------------------------
data "azurerm_key_vault" "ad_key_vault" {
  name                = var.vault_name
  resource_group_name = var.network_group_name
}

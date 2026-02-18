# ==================================================================================================
# AzureRM Provider and Core Resource Group Setup
# - Configures Azure provider features
# - Defines subscription and client data sources
# - Declares input variables for RG name and location
# - Creates the primary resource group for deployment
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Configure AzureRM provider
# --------------------------------------------------------------------------------------------------
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true   # Purge Key Vault immediately on destroy
      recover_soft_deleted_key_vaults = false  # Do not auto-recover deleted Key Vaults
    }

    resource_group {
      prevent_deletion_if_contains_resources = false # Allow deletion of RG even if non-empty
    }
  }
}

# --------------------------------------------------------------------------------------------------
# Fetch subscription details (subscription ID, display name, etc.)
# --------------------------------------------------------------------------------------------------
data "azurerm_subscription" "primary" {}

# --------------------------------------------------------------------------------------------------
# Fetch details of the authenticated client (SPN or user identity)
# --------------------------------------------------------------------------------------------------
data "azurerm_client_config" "current" {}

# --------------------------------------------------------------------------------------------------
# Create the Resource Groups
# --------------------------------------------------------------------------------------------------

# Primary resource group for AD-related resources
resource "azurerm_resource_group" "ad" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

# Resource group for RStudio VM scale set resources
resource "azurerm_resource_group" "vmss" {
  name     = var.vmss_resource_group_name
  location = var.resource_group_location
}

# Resource group for standalone RStudio servers
resource "azurerm_resource_group" "servers" {
  name     = var.servers_resource_group_name
  location = var.resource_group_location
}
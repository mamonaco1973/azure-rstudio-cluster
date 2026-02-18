# ==============================================================================
# File: main.tf
# ==============================================================================
# Purpose:
#   - Configure AzureRM provider.
#   - Retrieve subscription and client execution context.
#   - Reference existing resource groups, image, network, and Key Vault.
#
# Notes:
#   - This module assumes core infrastructure already exists.
#   - All resources defined here are data lookups only.
# ==============================================================================


# ------------------------------------------------------------------------------
# Azure Provider
# ------------------------------------------------------------------------------
# Enables AzureRM provider with default feature configuration.
# ------------------------------------------------------------------------------
provider "azurerm" {
  features {}
}


# ------------------------------------------------------------------------------
# Subscription and Client Context
# ------------------------------------------------------------------------------
# Retrieves metadata about the active subscription and identity.
# ------------------------------------------------------------------------------
data "azurerm_subscription" "primary" {}

data "azurerm_client_config" "current" {}


# ------------------------------------------------------------------------------
# Resource Groups
# ------------------------------------------------------------------------------
# cluster_rg:
#   - Contains custom image and cluster-related resources.
#
# project_rg:
#   - Contains networking and shared infrastructure components.
# ------------------------------------------------------------------------------
data "azurerm_resource_group" "cluster_rg" {
  name = var.cluster_group_name
}

data "azurerm_resource_group" "project_rg" {
  name = var.project_group_name
}


# ------------------------------------------------------------------------------
# Managed Image Lookup
# ------------------------------------------------------------------------------
# References prebuilt RStudio Managed Image created by Packer.
# Used as source image for VM or VM Scale Set deployments.
# ------------------------------------------------------------------------------
data "azurerm_image" "rstudio_image" {
  name                = var.rstudio_image_name
  resource_group_name = data.azurerm_resource_group.cluster_rg.name
}


# ------------------------------------------------------------------------------
# Virtual Network Lookup
# ------------------------------------------------------------------------------
# References existing VNet where cluster resources are deployed.
# ------------------------------------------------------------------------------
data "azurerm_virtual_network" "cluster_vnet" {
  name                = var.vnet_name
  resource_group_name = data.azurerm_resource_group.project_rg.name
}


# ------------------------------------------------------------------------------
# Cluster Subnet Lookup
# ------------------------------------------------------------------------------
# Subnet used by RStudio VM instances or VM Scale Set.
# ------------------------------------------------------------------------------
data "azurerm_subnet" "cluster_subnet" {
  name                 = var.subnet_name
  virtual_network_name = data.azurerm_virtual_network.cluster_vnet.name
  resource_group_name  = data.azurerm_resource_group.project_rg.name
}


# ------------------------------------------------------------------------------
# Application Gateway Subnet Lookup
# ------------------------------------------------------------------------------
# Dedicated subnet required for Azure Application Gateway.
# ------------------------------------------------------------------------------
data "azurerm_subnet" "app_gateway_subnet" {
  name                 = "app-gateway-subnet"
  virtual_network_name = data.azurerm_virtual_network.cluster_vnet.name
  resource_group_name  = data.azurerm_resource_group.project_rg.name
}


# ------------------------------------------------------------------------------
# Key Vault Lookup
# ------------------------------------------------------------------------------
# References existing Key Vault used for credentials and secrets.
# ------------------------------------------------------------------------------
data "azurerm_key_vault" "ad_key_vault" {
  name                = var.vault_name
  resource_group_name = data.azurerm_resource_group.project_rg.name
}

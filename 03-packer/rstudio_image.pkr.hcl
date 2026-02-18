# ==============================================================================
# File: rstudio_image.pkr.hcl
# ==============================================================================
# Purpose:
#   - Build custom Azure Managed Image with RStudio Server.
#   - Base image: Ubuntu 24.04 LTS (Canonical).
#   - Install base packages, Azure CLI, and RStudio Server.
#   - Produce timestamped Managed Image for Terraform use.
#
# Notes:
#   - Uses azure-arm builder plugin.
#   - Image name includes compact timestamp for uniqueness.
# ==============================================================================


# ------------------------------------------------------------------------------
# Packer Plugin Configuration
# ------------------------------------------------------------------------------
# Declares required Azure plugin for Packer.
# Locks to major version 2 for stability.
# ------------------------------------------------------------------------------
packer {
  required_plugins {
    azure = {
      source   = "github.com/hashicorp/azure"
      version  = "~> 2"
    }
  }
}

# ------------------------------------------------------------------------------
# Local Variables
# ------------------------------------------------------------------------------
# Generates compact timestamp (YYYYMMDDHHMMSS).
# Used to create unique managed image name.
# ------------------------------------------------------------------------------
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

# ------------------------------------------------------------------------------
# Variables: Azure Authentication
# ------------------------------------------------------------------------------
# Required for azure-arm builder authentication.
# Typically provided via environment variables or CLI flags.
# ------------------------------------------------------------------------------
variable "client_id" {
  description = "Azure AD Application (Client) ID"
  type        = string
}

variable "client_secret" {
  description = "Azure AD Application (Client) Secret"
  type        = string
}

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure Tenant (Directory) ID"
  type        = string
}

variable "resource_group" {
  description = "Azure Resource Group where the custom image will be created"
  type        = string
}

# ------------------------------------------------------------------------------
# Source: Azure ARM Builder
# ------------------------------------------------------------------------------
# Launches temporary Ubuntu 24.04 VM.
# Installs software via provisioners.
# Captures Managed Image into specified resource group.
# ------------------------------------------------------------------------------
source "azure-arm" "rstudio_image" {

  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  image_offer     = "ubuntu-24_04-lts"
  image_publisher = "canonical"
  image_sku       = "server"
  
  ssh_username    = "ubuntu"

  location        = "Central US"
  vm_size         = "Standard_DS1_v2"
  os_type         = "Linux"

  os_disk_size_gb           = 64

  managed_image_name                 = "rstudio_image_${local.timestamp}"
  managed_image_resource_group_name  = var.resource_group
}

# ------------------------------------------------------------------------------
# Build Block
# ------------------------------------------------------------------------------
# Executes shell provisioners inside temporary VM.
# Each script installs specific components.
# ------------------------------------------------------------------------------
build {
  sources = ["source.azure-arm.rstudio_image"]  

  provisioner "shell" {
    script          = "./packages.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  provisioner "shell" {
    script          = "./azcli.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  provisioner "shell" {
    script          = "./rstudio.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }
}

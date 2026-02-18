# ==============================================================================
# File: variables.tf
# ==============================================================================
# Purpose:
#   - Define Active Directory identity parameters.
#   - Define custom image and infrastructure placement inputs.
#   - Provide defaults for networking and resource groups.
#
# Notes:
#   - Defaults reflect lab/dev environment values.
#   - Production deployments should override via tfvars or CLI.
# ==============================================================================


# ------------------------------------------------------------------------------
# AD DNS Zone
# ------------------------------------------------------------------------------
# Fully Qualified Domain Name used by Samba AD.
# Defines DNS namespace and domain identity.
# ------------------------------------------------------------------------------
variable "dns_zone" {
  description = "AD DNS zone / domain (e.g., rstudio.mikecloud.com)"
  type        = string
  default     = "rstudio.mikecloud.com"
}


# ------------------------------------------------------------------------------
# Kerberos Realm
# ------------------------------------------------------------------------------
# Uppercase representation of DNS domain.
# Required for Kerberos and AD authentication flows.
# ------------------------------------------------------------------------------
variable "realm" {
  description = "Kerberos realm (e.g., RSTUDIO.MIKECLOUD.COM)"
  type        = string
  default     = "RSTUDIO.MIKECLOUD.COM"
}


# ------------------------------------------------------------------------------
# NetBIOS Name
# ------------------------------------------------------------------------------
# Short legacy domain name (<=15 characters).
# Used by SMB/CIFS and older clients.
# ------------------------------------------------------------------------------
variable "netbios" {
  description = "NetBIOS short domain name (e.g., RSTUDIO)"
  type        = string
  default     = "RSTUDIO"
}


# ------------------------------------------------------------------------------
# LDAP User Base DN
# ------------------------------------------------------------------------------
# Distinguished Name subtree where user accounts reside.
# ------------------------------------------------------------------------------
variable "user_base_dn" {
  description = "User base DN for LDAP (e.g., CN=Users,DC=rstudio,DC=mikecloud,DC=com)"
  type        = string
  default     = "CN=Users,DC=rstudio,DC=mikecloud,DC=com"
}


# ------------------------------------------------------------------------------
# RStudio Custom Image Name
# ------------------------------------------------------------------------------
# Managed image name created via Packer build.
# ------------------------------------------------------------------------------
variable "rstudio_image_name" {
  description = "Name of the RStudio custom image"
  type        = string
}


# ------------------------------------------------------------------------------
# Virtual Network Name
# ------------------------------------------------------------------------------
# Existing VNet where cluster resources are deployed.
# ------------------------------------------------------------------------------
variable "vnet_name" {
  description = "Name of the existing virtual network"
  type        = string
  default     = "ad-vnet"
}


# ------------------------------------------------------------------------------
# Subnet Name
# ------------------------------------------------------------------------------
# Existing subnet used for VM or VMSS placement.
# ------------------------------------------------------------------------------
variable "subnet_name" {
  description = "Name of the existing subnet"
  type        = string
  default     = "vm-subnet"
}


# ------------------------------------------------------------------------------
# Project Resource Group
# ------------------------------------------------------------------------------
# Resource group containing shared networking resources.
# ------------------------------------------------------------------------------
variable "project_group_name" {
  description = "Resource group used for the network resources"
  type        = string
  default     = "rstudio-network-rg"
}


# ------------------------------------------------------------------------------
# Cluster Resource Group
# ------------------------------------------------------------------------------
# Resource group containing VMSS and image resources.
# ------------------------------------------------------------------------------
variable "cluster_group_name" {
  description = "Resource group used for the image and network resources"
  type        = string
  default     = "rstudio-vmss-rg"
}


# ------------------------------------------------------------------------------
# Ubuntu Password
# ------------------------------------------------------------------------------
# Password used for Ubuntu VM instances.
# Should be provided securely via tfvars or environment variable.
# ------------------------------------------------------------------------------
variable "ubuntu_password" {
  description = "Password for the Ubuntu VM"
  type        = string
}


# ------------------------------------------------------------------------------
# NFS Storage Account Name
# ------------------------------------------------------------------------------
# Name of existing storage account hosting Azure Files (NFS).
# ------------------------------------------------------------------------------
variable "nfs_storage_account" {
  description = "Name of the NFS storage account"
  type        = string
}


# ------------------------------------------------------------------------------
# Key Vault Name
# ------------------------------------------------------------------------------
# Existing Azure Key Vault used for secret storage.
# ------------------------------------------------------------------------------
variable "vault_name" {
  description = "The name of the Azure Key Vault for storing secrets"
  type        = string
}

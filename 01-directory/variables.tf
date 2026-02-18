# ==============================================================================
# File: variables.tf
# ==============================================================================
# Purpose:
#   - Define Active Directory identity inputs.
#   - Control optional Bastion deployment.
#   - Define resource group naming and placement variables.
#
# Notes:
#   - Defaults reflect Quick Start lab configuration.
#   - Production deployments should override via tfvars or CLI.
# ==============================================================================

# ------------------------------------------------------------------------------
# DNS Zone (FQDN)
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
# Required for Kerberos configuration and AD authentication.
# ------------------------------------------------------------------------------
variable "realm" {
  description = "Kerberos realm (usually DNS zone in UPPERCASE, e.g., RSTUDIO.MIKECLOUD.COM)"
  type        = string
  default     = "RSTUDIO.MIKECLOUD.COM"
}

# ------------------------------------------------------------------------------
# NetBIOS Name
# ------------------------------------------------------------------------------
# Short legacy domain name (<=15 characters).
# Used by SMB/CIFS and older Windows clients.
# ------------------------------------------------------------------------------
variable "netbios" {
  description = "NetBIOS short domain name (e.g., RSTUDIO)"
  type        = string
  default     = "RSTUDIO"
}

# ------------------------------------------------------------------------------
# LDAP User Base DN
# ------------------------------------------------------------------------------
# Distinguished Name subtree where user objects reside.
# ------------------------------------------------------------------------------
variable "user_base_dn" {
  description = "User base DN for LDAP (e.g., CN=Users,DC=rstudio,DC=mikecloud,DC=com)"
  type        = string
  default     = "CN=Users,DC=rstudio,DC=mikecloud,DC=com"
}

# ------------------------------------------------------------------------------
# Bastion Support Toggle
# ------------------------------------------------------------------------------
# Controls whether Azure Bastion resources are deployed.
# True  = Deploy Bastion infrastructure.
# False = Skip Bastion-related resources.
# ------------------------------------------------------------------------------
variable "bastion_support" {
  description = "Deploy Azure Bastion resources"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Primary Resource Group
# ------------------------------------------------------------------------------
# Defines name and Azure region for main deployment group.
# ------------------------------------------------------------------------------
variable "resource_group_name" {
  description = "Azure resource group name."
  type        = string
  default     = "rstudio-network-rg"
}

variable "resource_group_location" {
  description = "Azure region for resource group."
  type        = string
  default     = "Central US"
}

# ------------------------------------------------------------------------------
# VMSS Resource Group
# ------------------------------------------------------------------------------
# Resource group containing RStudio VM scale set.
# ------------------------------------------------------------------------------
variable "vmss_resource_group_name" {
  description = "Resource group name for RStudio VM scale set."
  type        = string
  default     = "rstudio-vmss-rg"
}

# ------------------------------------------------------------------------------
# Servers Resource Group
# ------------------------------------------------------------------------------
# Resource group containing standalone RStudio servers.
# ------------------------------------------------------------------------------
variable "servers_resource_group_name" {
  description = "Resource group name for standalone RStudio servers."
  type        = string
  default     = "rstudio-servers-rg"
}

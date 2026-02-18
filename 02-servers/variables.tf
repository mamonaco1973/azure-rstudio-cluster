# ==============================================================================
# File: variables.tf
# ==============================================================================
# Purpose:
#   - Define Active Directory identity inputs for Samba AD.
#   - Define resource group placement variables.
#   - Define Key Vault reference input.
#
# Notes:
#   - Defaults reflect lab/dev configuration.
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
# Required for Kerberos authentication configuration.
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
# Used by SMB/CIFS and legacy Windows clients.
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
# Networking Resource Group
# ------------------------------------------------------------------------------
# Resource group containing virtual network and shared networking resources.
# ------------------------------------------------------------------------------
variable "network_group_name" {
  description = "The name of the Azure Resource Group for networking."
  type        = string
  default     = "rstudio-network-rg"
}

# ------------------------------------------------------------------------------
# Servers Resource Group
# ------------------------------------------------------------------------------
# Resource group containing VM and server resources.
# ------------------------------------------------------------------------------
variable "servers_group_name" {
  description = "The name of the Azure Resource Group for networking."
  type        = string
  default     = "rstudio-servers-rg"
}

# ------------------------------------------------------------------------------
# Key Vault Name
# ------------------------------------------------------------------------------
# Existing Azure Key Vault used for credential and secret storage.
# Must be supplied via CLI, tfvars, or environment variable.
# ------------------------------------------------------------------------------
variable "vault_name" {
  description = "The name of the Azure Key Vault for storing secrets"
  type        = string
  # default   = "ad-key-vault-qcxu2ksw"
}

variable "resource_group_location" {
  description = "Azure region for resource group."
  type        = string
  default     = "Central US"
}

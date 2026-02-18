# ==============================================================================
# File: nfs.tf
# ==============================================================================
# Purpose:
#   - Deploy Azure Files (NFS 4.1) using Premium FileStorage.
#   - Expose the file share privately via Private Endpoint.
#   - Provide private DNS resolution inside the VNet.
#
# Design:
#   - Public network access is disabled.
#   - Traffic flows only through Private Endpoint.
#   - Linux VMs mount via NFS 4.1 inside the VNet.
# ==============================================================================

# ------------------------------------------------------------------------------
# Storage Account (Premium FileStorage)
# ------------------------------------------------------------------------------
# Requirements:
#   - account_kind = FileStorage
#   - account_tier = Premium
#   - NFS requires Premium FileStorage.
#   - Name must be globally unique and lowercase.
# ------------------------------------------------------------------------------
resource "azurerm_storage_account" "nfs_storage_account" {

  name                          = "nfs${random_string.vm_suffix.result}"
  resource_group_name           = data.azurerm_resource_group.servers.name
  location                      = data.azurerm_resource_group.servers.location
  account_kind                  = "FileStorage"
  account_tier                  = "Premium"
  account_replication_type      = "LRS"
  public_network_access_enabled = false
}

# ------------------------------------------------------------------------------
# NFS File Share
# ------------------------------------------------------------------------------
# Creates NFS 4.1-enabled share.
# Premium FileStorage requires minimum 100 GiB quota.
# ------------------------------------------------------------------------------
resource "azurerm_storage_share" "nfs" {
  name               = "nfs"
  storage_account_id = azurerm_storage_account.nfs_storage_account.id
  enabled_protocol   = "NFS"
  quota              = 100
}

# ------------------------------------------------------------------------------
# Private DNS Zone
# ------------------------------------------------------------------------------
# Enables private resolution of:
#   <account>.file.core.windows.net
# to the private endpoint IP inside the VNet.
# ------------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = data.azurerm_resource_group.servers.name
}

# ------------------------------------------------------------------------------
# DNS Zone VNet Link
# ------------------------------------------------------------------------------
# Links DNS zone to AD VNet for internal resolution.
# ------------------------------------------------------------------------------
resource "azurerm_private_dns_zone_virtual_network_link" "file_link" {
  name                  = "vnet-link"
  resource_group_name   = data.azurerm_resource_group.servers.name
  private_dns_zone_name = azurerm_private_dns_zone.file.name
  virtual_network_id    = data.azurerm_virtual_network.ad_vnet.id
}

# ------------------------------------------------------------------------------
# Private Endpoint
# ------------------------------------------------------------------------------
# Creates private connectivity to storage account "file" subresource.
# ------------------------------------------------------------------------------
resource "azurerm_private_endpoint" "pe_file" {
  name                = "pe-st-file"
  location            = data.azurerm_resource_group.servers.location
  resource_group_name = data.azurerm_resource_group.servers.name
  subnet_id           = data.azurerm_subnet.vm_subnet.id

  # --------------------------------------------------------------------------
  # Private Service Connection
  # --------------------------------------------------------------------------
  private_service_connection {
    name                           = "sc-st-file"
    private_connection_resource_id = azurerm_storage_account.nfs_storage_account.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  # --------------------------------------------------------------------------
  # Private DNS Zone Group
  # --------------------------------------------------------------------------
  private_dns_zone_group {
    name                 = "pdzg-file"
    private_dns_zone_ids = [azurerm_private_dns_zone.file.id]
  }
}

# ------------------------------------------------------------------------------
# Optional Output: Linux Mount Command
# ------------------------------------------------------------------------------
# Provides reference mount command. Disabled by default.
# ------------------------------------------------------------------------------
# output "nfs_mount_command" {
#   value = <<EOT
# sudo apt-get -y install nfs-common
# sudo mkdir -p /mnt/azurefiles
# sudo mount -t nfs -o vers=4.1,sec=sys \
#   ${azurerm_storage_account.nfs_storage_account.name}.file.core.windows.net:/${azurerm_storage_share.nfs.name} /mnt/azurefiles
# EOT
# }

# ==============================================================================
# File: nfs_gateway.tf
# ==============================================================================
# Purpose:
#   - Deploy Ubuntu-based NFS Gateway VM.
#   - Generate secure credentials for the ubuntu account.
#   - Store credentials in Azure Key Vault.
#   - Attach NIC and enable managed identity for secret access.
#
# Notes:
#   - Intended for lab/dev environments.
#   - Password authentication is enabled for simplicity.
# ==============================================================================

# ------------------------------------------------------------------------------
# Ubuntu Password
# Generates a 24-character password with restricted special characters.
# ------------------------------------------------------------------------------
resource "random_password" "ubuntu_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# ------------------------------------------------------------------------------
# Key Vault Secret
# Stores ubuntu credentials as a JSON object in the existing Key Vault.
# ------------------------------------------------------------------------------
resource "azurerm_key_vault_secret" "ubuntu_secret" {
  name         = "ubuntu-credentials"
  value        = jsonencode({
    username = "ubuntu",
    password = random_password.ubuntu_password.result
  })
  key_vault_id = data.azurerm_key_vault.ad_key_vault.id
  content_type = "application/json"
}

# ------------------------------------------------------------------------------
# Network Interface
# Creates NIC attached to existing VM subnet.
# ------------------------------------------------------------------------------
resource "azurerm_network_interface" "nfs_gateway_nic" {
  name                = "nfs-gateway-nic"
  location            = data.azurerm_resource_group.servers.location
  resource_group_name = data.azurerm_resource_group.servers.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# ------------------------------------------------------------------------------
# Linux Virtual Machine
# Deploys Ubuntu 24.04 LTS VM with system-assigned managed identity.
# ------------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "nfs_gateway" {
  name                            = "nfs-gateway-${random_string.vm_suffix.result}"
  location                        = data.azurerm_resource_group.servers.location
  resource_group_name             = data.azurerm_resource_group.servers.name
  size                            = "Standard_B1s"
  admin_username                  = "ubuntu"
  admin_password                  = random_password.ubuntu_password.result
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nfs_gateway_nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("./scripts/custom_data.sh", {
    vault_name      = data.azurerm_key_vault.ad_key_vault.name
    domain_fqdn     = var.dns_zone
    netbios         = var.netbios
    force_group     = "rstudio-users"
    realm           = var.realm
    storage_account = azurerm_storage_account.nfs_storage_account.name
  }))

  identity {
    type = "SystemAssigned"
  }
}

# ------------------------------------------------------------------------------
# Role Assignment
# Grants VM managed identity permission to read Key Vault secrets.
# ------------------------------------------------------------------------------
resource "azurerm_role_assignment" "vm_lnx_key_vault_secrets_user" {
  scope                = data.azurerm_key_vault.ad_key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.nfs_gateway.identity[0].principal_id
}

# ==============================================================================
# File: nfs_gateway.tf
# ==============================================================================
# Purpose:
#   - Deploy Ubuntu-based NFS Gateway VM.
#   - Generate secure credentials for the ubuntu account.
#   - Store credentials in Azure Key Vault.
#   - Attach NIC and enable managed identity for secret access.
#
# Changes:
#   - Adds a Public IP and attaches it to the VM NIC.
#   - Sets the Public IP DNS label to match the VM instance name.
#
# Notes:
#   - Intended for lab/dev environments.
#   - Password authentication is enabled for simplicity.
#   - Ensure NSG rules allow inbound SSH (22) if you need direct access.
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
    username = "ubuntu"
    password = random_password.ubuntu_password.result
  })
  key_vault_id = data.azurerm_key_vault.ad_key_vault.id
  content_type = "application/json"
}

# ==============================================================================
# Locals (NEW)
# ==============================================================================
# Uses a single computed name for:
#   - VM name
#   - Public IP DNS label
# ==============================================================================
locals {
  nfs_gateway_name = "nfs-gateway-${random_string.vm_suffix.result}"
}

# ==============================================================================
# Public IP (NEW)
# ==============================================================================
# Creates a Public IP and assigns a DNS label that matches the VM name.
#
# DNS:
#   - FQDN format: <domain_name_label>.<region>.cloudapp.azure.com
#   - domain_name_label must be unique within the Azure region.
# ==============================================================================
resource "azurerm_public_ip" "nfs_gateway_pip" {
  name                = "${local.nfs_gateway_name}-pip"
  location            = data.azurerm_resource_group.servers.location
  resource_group_name = data.azurerm_resource_group.servers.name

  allocation_method   = "Static"
  sku                 = "Standard"

  domain_name_label   = local.nfs_gateway_name
}

# ------------------------------------------------------------------------------
# Network Interface
# Creates NIC attached to existing VM subnet.
# Adds Public IP association to make the VM publicly reachable.
# ------------------------------------------------------------------------------
resource "azurerm_network_interface" "nfs_gateway_nic" {
  name                = "nfs-gateway-nic"
  location            = data.azurerm_resource_group.servers.location
  resource_group_name = data.azurerm_resource_group.servers.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.nfs_gateway_pip.id
  }
}

# ------------------------------------------------------------------------------
# Linux Virtual Machine
# Deploys Ubuntu 24.04 LTS VM with system-assigned managed identity.
# ------------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "nfs_gateway" {
  name                            = local.nfs_gateway_name
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

# ==============================================================================
# Outputs (Optional)
# ==============================================================================
# Uncomment if you want to quickly grab the public FQDN for SSH testing.
# ==============================================================================
# output "nfs_gateway_public_fqdn" {
#   value       = azurerm_public_ip.nfs_gateway_pip.fqdn
#   description = "Public FQDN for the NFS gateway (cloudapp.azure.com)."
# }
#
# output "nfs_gateway_public_ip" {
#   value       = azurerm_public_ip.nfs_gateway_pip.ip_address
#   description = "Public IP address for the NFS gateway."
# }

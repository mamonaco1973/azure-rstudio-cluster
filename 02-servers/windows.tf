# ==============================================================================
# File: windows.tf
# ==============================================================================
# Purpose:
#   - Deploy Windows Server VM for AD integration.
#   - Generate secure admin credentials.
#   - Store credentials in Key Vault.
#   - Join VM to domain using Custom Script Extension.
#
# Notes:
#   - VM uses system-assigned managed identity.
#   - Key Vault access granted via RBAC role assignment.
#   - Domain join script is pulled from private blob via SAS.
# ==============================================================================

# ------------------------------------------------------------------------------
# Windows Admin Password
# ------------------------------------------------------------------------------
# Generates secure 24-character password for adminuser account.
# ------------------------------------------------------------------------------
resource "random_password" "win_adminuser_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# ------------------------------------------------------------------------------
# VM Name Suffix
# ------------------------------------------------------------------------------
# Generates lowercase suffix for resource name uniqueness.
# ------------------------------------------------------------------------------
resource "random_string" "vm_suffix" {
  length  = 6
  special = false
  upper   = false
}

# ------------------------------------------------------------------------------
# Key Vault Secret
# ------------------------------------------------------------------------------
# Stores adminuser credentials as JSON in existing Key Vault.
# ------------------------------------------------------------------------------
resource "azurerm_key_vault_secret" "win_adminuser_secret" {
  name         = "win-adminuser-credentials"
  value        = jsonencode({
    username = "adminuser",
    password = random_password.win_adminuser_password.result
  })
  key_vault_id = data.azurerm_key_vault.ad_key_vault.id
  content_type = "application/json"
}

# ------------------------------------------------------------------------------
# Network Interface
# ------------------------------------------------------------------------------
# Attaches Windows VM to existing VM subnet.
# ------------------------------------------------------------------------------
resource "azurerm_network_interface" "windows_vm_nic" {
  name                = "windows-vm-nic"
  location            = data.azurerm_resource_group.servers.location
  resource_group_name = data.azurerm_resource_group.servers.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# ------------------------------------------------------------------------------
# Windows Virtual Machine
# ------------------------------------------------------------------------------
# Deploys Windows Server 2022 Datacenter.
# Uses system-assigned identity for Key Vault access.
# ------------------------------------------------------------------------------
resource "azurerm_windows_virtual_machine" "windows_ad_instance" {
  name                = "win-ad-${random_string.vm_suffix.result}"
  location            = data.azurerm_resource_group.servers.location
  resource_group_name = data.azurerm_resource_group.servers.name
  size                = "Standard_DS1_v2"
  admin_username      = "adminuser"
  admin_password      = random_password.win_adminuser_password.result

  network_interface_ids = [
    azurerm_network_interface.windows_vm_nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}

# ------------------------------------------------------------------------------
# Key Vault RBAC Role
# ------------------------------------------------------------------------------
# Grants VM identity permission to read secrets.
# ------------------------------------------------------------------------------
resource "azurerm_role_assignment" "vm_win_key_vault_secrets_user" {
  scope                = data.azurerm_key_vault.ad_key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         =  azurerm_windows_virtual_machine.windows_ad_instance.identity[0].principal_id
}

# ------------------------------------------------------------------------------
# Custom Script Extension
# ------------------------------------------------------------------------------
# Downloads AD join script from private blob via SAS.
# Executes script and logs output locally on VM.
# ------------------------------------------------------------------------------
resource "azurerm_virtual_machine_extension" "join_script" {
  name                 = "customScript"
  virtual_machine_id   =  azurerm_windows_virtual_machine.windows_ad_instance.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = <<SETTINGS
  {
    "fileUris": [
      "https://${azurerm_storage_account.scripts_storage.name}.blob.core.windows.net/${azurerm_storage_container.scripts.name}/${azurerm_storage_blob.ad_join_script.name}?${data.azurerm_storage_account_sas.script_sas.sas}"
    ],
    "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted -File ad-join.ps1 *>> C:\\WindowsAzure\\Logs\\ad-join.log"
  }
  SETTINGS

  depends_on = [
    azurerm_role_assignment.vm_win_key_vault_secrets_user,
    azurerm_linux_virtual_machine.nfs_gateway
  ]
}

# ------------------------------------------------------------------------------
# Output: AD Join Script URL
# ------------------------------------------------------------------------------
# Exposes script URL with SAS token for troubleshooting.
# Marked sensitive to prevent accidental disclosure.
# ------------------------------------------------------------------------------
# output "ad_join_script_url" {
#   value =
#     "https://${azurerm_storage_account.scripts_storage.name}.blob.core.windows.net/${azurerm_storage_container.scripts.name}/${azurerm_storage_blob.ad_join_script.name}?${data.azurerm_storage_account_sas.script_sas.sas}"
#   description = "URL to the AD join script with SAS token."
#   sensitive   = true
# }

# ==========================================================================================
# Networking and Virtual Machine Resources
# ------------------------------------------------------------------------------------------
# Defines the public IP, NIC, and Linux VM for RStudio deployment on Azure
# ==========================================================================================


# ------------------------------------------------------------------------------------------
# Public IP
# - Provides a static public IP with DNS label for external access
# ------------------------------------------------------------------------------------------
resource "azurerm_public_ip" "rstudio_pip" {
  name                = "rstudio-pip"
  location            = data.azurerm_resource_group.cluster_rg.location
  resource_group_name = data.azurerm_resource_group.cluster_rg.name
  allocation_method   = "Static"   # Use static IP for predictable connectivity
  sku                 = "Standard" # Standard SKU recommended for production

  # Generate a globally unique DNS label using the subscription ID prefix
  domain_name_label = "rstudio-${substr(data.azurerm_client_config.current.subscription_id, 0, 6)}"
}


# ------------------------------------------------------------------------------------------
# Network Interface
# - Attaches VM to the subnet and binds the public IP
# ------------------------------------------------------------------------------------------
resource "azurerm_network_interface" "rstudio_nic" {
  name                = "rstudio-nic"
  location            = data.azurerm_resource_group.cluster_rg.location
  resource_group_name = data.azurerm_resource_group.cluster_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.cluster_subnet.id
    private_ip_address_allocation = "Dynamic" # Auto-assign private IP
    public_ip_address_id          = azurerm_public_ip.rstudio_pip.id
  }
}


# ------------------------------------------------------------------------------------------
# Linux Virtual Machine
# - Deploys an Ubuntu VM from the custom RStudio image
# ------------------------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "rstudio_vm" {
  name                            = "rstudio-vm"
  location                        = data.azurerm_resource_group.cluster_rg.location
  resource_group_name             = data.azurerm_resource_group.cluster_rg.name
  size                            = "Standard_B1s"      # Lightweight VM size
  admin_username                  = "ubuntu"            # Default login user
  admin_password                  = var.ubuntu_password # Securely injected password
  disable_password_authentication = false               # Enable password login (set true for SSH-only)

  network_interface_ids = [
    azurerm_network_interface.rstudio_nic.id # Attach defined NIC
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS" # Cost-effective, locally redundant storage
  }

  # Use custom image produced by Packer
  source_image_id = data.azurerm_image.rstudio_image.id

  # Cloud-init script to bootstrap RStudio and domain integration
  custom_data = base64encode(templatefile("${path.module}/scripts/rstudio_booter.sh", {
    vault_name      = data.azurerm_key_vault.ad_key_vault.name
    domain_fqdn     = var.dns_zone
    storage_account = var.nfs_storage_account
    netbios         = var.netbios
    realm           = var.realm
    force_group     = "rstudio-users"
  }))
}

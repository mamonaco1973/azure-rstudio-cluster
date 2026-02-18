# ==============================================================================
# File: vmss.tf
# ==============================================================================
# Purpose:
#   - Deploy Linux VM Scale Set (VMSS) for RStudio Server cluster.
#   - Register instances in Application Gateway backend pool.
#   - Bootstrap instances via cloud-init for AD join and NFS integration.
#   - Enable health monitoring and automatic instance repair.
#   - Configure CPU-based autoscale profile.
#   - Grant VMSS identity permission to read Key Vault secrets.
#
# Notes:
#   - Password authentication is enabled for lab/dev convenience.
#   - Health extension checks RStudio login endpoint on port 8787.
# ==============================================================================

# ------------------------------------------------------------------------------
# Linux VM Scale Set
# ------------------------------------------------------------------------------
# Deploys VMSS instances from custom Managed Image.
# Attaches instances to Application Gateway backend pool.
# Bootstraps instances using cloud-init template.
# ------------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine_scale_set" "rstudio_vmss" {
  name                = "rstudio-vmss"
  location            = data.azurerm_resource_group.cluster_rg.location
  resource_group_name = data.azurerm_resource_group.cluster_rg.name

  sku                            = "Standard_DS1_v2"
  instances                      = 2
  admin_username                 = "ubuntu"
  admin_password                 = var.ubuntu_password
  disable_password_authentication = false
  source_image_id                = data.azurerm_image.rstudio_image.id

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # --------------------------------------------------------------------------
  # Networking
  # --------------------------------------------------------------------------
  # Primary NIC attaches to cluster subnet.
  # IP config registers into App Gateway backend pool.
  # --------------------------------------------------------------------------
  network_interface {
    name    = "rstudio-vmss-nic"
    primary = true

    ip_configuration {
      name      = "internal"
      subnet_id = data.azurerm_subnet.cluster_subnet.id

      application_gateway_backend_address_pool_ids = [
        tolist(azurerm_application_gateway.rstudio_app_gateway.backend_address_pool)[0].id
      ]
    }
  }

  # --------------------------------------------------------------------------
  # Bootstrap (cloud-init)
  # --------------------------------------------------------------------------
  # Template injects domain and storage settings for:
  #   - AD domain join
  #   - RStudio configuration
  #   - NFS-backed Samba integration
  # --------------------------------------------------------------------------
  custom_data = base64encode(templatefile("${path.module}/scripts/rstudio_booter.sh", {
    vault_name      = data.azurerm_key_vault.ad_key_vault.name
    domain_fqdn     = var.dns_zone
    storage_account = var.nfs_storage_account
    netbios         = var.netbios
    realm           = var.realm
    force_group     = "rstudio-users"
  }))

  computer_name_prefix = "rstudio"
  upgrade_mode         = "Automatic"

  # --------------------------------------------------------------------------
  # Automatic Instance Repair
  # --------------------------------------------------------------------------
  # Repairs unhealthy instances after grace period.
  # --------------------------------------------------------------------------
  automatic_instance_repair {
    enabled      = true
    grace_period = "PT10M"
  }

  # --------------------------------------------------------------------------
  # Application Health Extension
  # --------------------------------------------------------------------------
  # Reports instance health based on HTTP probe to /auth-sign-in.
  # Used by Azure for monitoring and repair decisions.
  # --------------------------------------------------------------------------
  extension {
    name                 = "HealthExtension"
    publisher            = "Microsoft.ManagedServices"
    type                 = "ApplicationHealthLinux"
    type_handler_version = "1.0"

    settings = jsonencode({
      protocol    = "http"
      port        = 8787
      requestPath = "/auth-sign-in"
    })
  }

  # --------------------------------------------------------------------------
  # Managed Identity
  # --------------------------------------------------------------------------
  # System-assigned identity used for Key Vault access via RBAC.
  # --------------------------------------------------------------------------
  identity {
    type = "SystemAssigned"
  }
}

# ------------------------------------------------------------------------------
# Autoscale Settings
# ------------------------------------------------------------------------------
# Scales VMSS based on average CPU utilization.
# Current profile defines min/default/max and a scale-up rule.
# ------------------------------------------------------------------------------
resource "azurerm_monitor_autoscale_setting" "rstudio_vmss_autoscale" {
  name                = "rstudio-vmss-autoscale"
  location            = data.azurerm_resource_group.cluster_rg.location
  resource_group_name = data.azurerm_resource_group.cluster_rg.name
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.rstudio_vmss.id

  profile {
    name = "default"

    capacity {
      minimum = 1
      default = 2
      maximum = 4
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.rstudio_vmss.id
        operator           = "GreaterThan"
        statistic          = "Average"
        threshold          = 60
        time_grain         = "PT1M"
        time_window        = "PT1M"
        time_aggregation   = "Average"
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
}

# ------------------------------------------------------------------------------
# Key Vault Role Assignment
# ------------------------------------------------------------------------------
# Grants VMSS identity read access to Key Vault secrets.
# ------------------------------------------------------------------------------
resource "azurerm_role_assignment" "vm_vmss_key_vault_secrets_user" {
  scope                = data.azurerm_key_vault.ad_key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine_scale_set.rstudio_vmss.identity[0].principal_id
}

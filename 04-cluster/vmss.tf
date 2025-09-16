# Define the Linux VM scale set
resource "azurerm_linux_virtual_machine_scale_set" "rstudio_vmss" {
  name                = "rstudio-vmss"                                  # VM scale set name
  location            = data.azurerm_resource_group.cluster_rg.location # Azure region
  resource_group_name = data.azurerm_resource_group.cluster_rg.name     # Resource group name

  sku             = "Standard_B1s" # VM size
  instances       = 2              # Number of instances
  admin_username  = "ubuntu"       # Admin username
  admin_password  = var.ubuntu_password
  source_image_id = data.azurerm_image.rstudio_image.id
  zones           = ["1", "2"]                                 # Availability zones

  os_disk {
    caching              = "ReadWrite"    # OS disk caching option
    storage_account_type = "Standard_LRS" # Storage account type
  }

  network_interface {
    name    = "rstudio-vmss-nic" # NIC name
    primary = true        # Primary NIC

    ip_configuration {
      name      = "internal"                            # IP configuration name
      subnet_id = data.azurerm_subnet.cluster_subnet.id # Subnet ID
      application_gateway_backend_address_pool_ids = [
        azurerm_application_gateway.rstudio_app_gateway.backend_address_pool[0].id # Backend pool ID
      ]
    }
  }

  # Cloud-init script to bootstrap RStudio and domain integration
  custom_data = base64encode(templatefile("${path.module}/scripts/rstudio_booter.sh", {
    vault_name      = data.azurerm_key_vault.ad_key_vault.name
    domain_fqdn     = var.dns_zone
    storage_account = var.nfs_storage_account
    netbios         = var.netbios
    realm           = var.realm
    force_group     = "rstudio-users"
  }))

  computer_name_prefix = "rstudio"   # Computer name prefix
  upgrade_mode         = "Automatic" # Upgrade mode

  automatic_instance_repair {
    enabled      = true    # Enable automatic instance repair
    grace_period = "PT10M" # Grace period for repair
  }

  extension {
    name                 = "HealthExtension"           # Extension name
    publisher            = "Microsoft.ManagedServices" # Publisher
    type                 = "ApplicationHealthLinux"    # Extension type
    type_handler_version = "1.0"                       # Extension version

    settings = jsonencode({
      protocol    = "http", # Protocol used by the health extension
      port        = 8787,   # Port for health checks
      requestPath = "/"     # Request path for health checks
    })
  }

  identity {
    type = "SystemAssigned" # System-assigned managed identity
  }
}


# Define autoscale settings for the VM scale set
resource "azurerm_monitor_autoscale_setting" "rstudio_vmss_autoscale" {
  name                = "rstudio-vmss-autoscale"                                # Autoscale setting name
  location            = data.azurerm_resource_group.cluster_rg.location         # Azure region
  resource_group_name = data.azurerm_resource_group.cluster_rg.name             # Resource group name
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.rstudio_vmss.id # Target resource

  profile {
    name = "default" # Profile name

    capacity {
      minimum = 1 # Minimum instance count
      default = 2 # Default instance count
      maximum = 4 # Maximum instance count
    }

    # Scale up rule
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"                                        # Metric name
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.rstudio_vmss.id # Metric resource ID
        operator           = "GreaterThan"                                           # Comparison operator
        statistic          = "Average"                                               # Statistic used
        threshold          = 60                                                      # Threshold for scaling
        time_grain         = "PT1M"                                                  # Granularity
        time_window        = "PT1M"                                                  # Time window
        time_aggregation   = "Average"                                               # Aggregation type
      }

      scale_action {
        direction = "Increase"    # Scale direction
        type      = "ChangeCount" # Scale type
        value     = "1"           # Change count
        cooldown  = "PT1M"        # Cooldown period
      }
    }
  }
}

# --------------------------------------------------------------------------------------------------
# Grant VM's managed identity permission to read Key Vault secrets
# --------------------------------------------------------------------------------------------------
resource "azurerm_role_assignment" "vm_vmss_key_vault_secrets_user" {
  scope                = data.azurerm_key_vault.ad_key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine_scale_set.rstudio_vmss.identity[0].principal_id
}
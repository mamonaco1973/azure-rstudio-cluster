# ==============================================================================
# File: appgateway.tf
# ==============================================================================
# Purpose:
#   - Deploy Azure Application Gateway for RStudio cluster.
#   - Provide public HTTP entry point on port 80.
#   - Forward traffic to backend RStudio instances on port 8787.
#   - Configure custom health probe for availability monitoring.
#
# Design:
#   - Uses Standard_v2 SKU.
#   - Public IP includes randomized DNS suffix.
#   - Sticky sessions enabled for RStudio stateful sessions.
# ==============================================================================

# ------------------------------------------------------------------------------
# Random DNS Suffix
# ------------------------------------------------------------------------------
# Generates lowercase 6-character suffix for public FQDN uniqueness.
# ------------------------------------------------------------------------------
resource "random_string" "gateway_suffix" {
  length  = 6
  special = false
  upper   = false
}

# ------------------------------------------------------------------------------
# Public IP
# ------------------------------------------------------------------------------
# Static Standard SKU IP required for Application Gateway v2.
# DNS label produces public FQDN:
#   rstudio-cluster-<suffix>.<region>.cloudapp.azure.com
# ------------------------------------------------------------------------------
resource "azurerm_public_ip" "rstudio_app_gateway_pip" {
  name                = "rstudio-app-gateway-pip"
  location            = data.azurerm_resource_group.cluster_rg.location
  resource_group_name = data.azurerm_resource_group.cluster_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "rstudio-cluster-${random_string.gateway_suffix.result}"
}

# ------------------------------------------------------------------------------
# Application Gateway
# ------------------------------------------------------------------------------
# Routes HTTP traffic to RStudio backend pool.
# ------------------------------------------------------------------------------
resource "azurerm_application_gateway" "rstudio_app_gateway" {
  name                = "rstudio-app-gateway"
  location            = data.azurerm_resource_group.cluster_rg.location
  resource_group_name = data.azurerm_resource_group.cluster_rg.name

  # --------------------------------------------------------------------------
  # SKU Configuration
  # --------------------------------------------------------------------------
  # Standard_v2 supports autoscaling and modern features.
  # Capacity set to 1 for baseline deployment.
  # --------------------------------------------------------------------------
  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  # --------------------------------------------------------------------------
  # Gateway IP Configuration
  # --------------------------------------------------------------------------
  # Associates gateway with dedicated subnet.
  # --------------------------------------------------------------------------
  gateway_ip_configuration {
    name      = "app-gateway-ip-config"
    subnet_id = data.azurerm_subnet.app_gateway_subnet.id
  }

  # --------------------------------------------------------------------------
  # Frontend Configuration
  # --------------------------------------------------------------------------
  frontend_ip_configuration {
    name                 = "app-gateway-frontend"
    public_ip_address_id = azurerm_public_ip.rstudio_app_gateway_pip.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  # --------------------------------------------------------------------------
  # Backend Pool
  # --------------------------------------------------------------------------
  # VM Scale Set NICs register into this pool.
  # --------------------------------------------------------------------------
  backend_address_pool {
    name = "app-gateway-backend-pool"
  }

  # --------------------------------------------------------------------------
  # Backend HTTP Settings
  # --------------------------------------------------------------------------
  # Routes traffic to RStudio Server (port 8787).
  # Cookie affinity ensures session stickiness.
  # --------------------------------------------------------------------------
  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Enabled"
    path                  = "/"
    port                  = 8787
    protocol              = "Http"
    request_timeout       = 30
    host_name = azurerm_public_ip.rstudio_app_gateway_pip.fqdn
  }

  # --------------------------------------------------------------------------
  # Health Probe
  # --------------------------------------------------------------------------
  # Checks RStudio login endpoint for HTTP 200 response.
  # Backend marked unhealthy after 5 consecutive failures.
  # --------------------------------------------------------------------------
  probe {
    name                = "custom-health-probe"
    protocol            = "Http"
    path                = "/auth-sign-in"
    interval            = 5
    timeout             = 5
    unhealthy_threshold = 5
    port                = 8787
    pick_host_name_from_backend_http_settings = true
  }

  # --------------------------------------------------------------------------
  # HTTP Listener
  # --------------------------------------------------------------------------
  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "app-gateway-frontend"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  # --------------------------------------------------------------------------
  # Routing Rule
  # --------------------------------------------------------------------------
  # Basic rule forwards all HTTP traffic to backend pool.
  # --------------------------------------------------------------------------
  request_routing_rule {
    name                       = "http-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "app-gateway-backend-pool"
    backend_http_settings_name = "http-settings"
    priority                   = 1
  }
}

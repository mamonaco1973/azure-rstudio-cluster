# ==================================================================================================
# Virtual Network, Subnets, and Network Security Group
# - Creates VNet with dedicated subnets for VMs, mini-AD, and Bastion
# - Configures NSG to allow SSH and RDP
# - Associates NSG with VM subnet
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Define the Virtual Network
# --------------------------------------------------------------------------------------------------
resource "azurerm_virtual_network" "ad_vnet" {
  name                = "ad-vnet"
  address_space       = ["10.0.0.0/23"]                     # Overall VNet range
  location            = azurerm_resource_group.ad.location
  resource_group_name = azurerm_resource_group.ad.name
}

# --------------------------------------------------------------------------------------------------
# Define VM Subnet (10.0.0.0/25)
# --------------------------------------------------------------------------------------------------
resource "azurerm_subnet" "vm_subnet" {
  name                 = "vm-subnet"
  resource_group_name  = azurerm_resource_group.ad.name
  virtual_network_name = azurerm_virtual_network.ad_vnet.name
  address_prefixes     = ["10.0.0.0/25"]
}

# --------------------------------------------------------------------------------------------------
# Define Mini-AD Subnet (10.0.0.128/25)
# --------------------------------------------------------------------------------------------------
resource "azurerm_subnet" "mini_ad_subnet" {
  name                 = "mini-ad-subnet"
  resource_group_name  = azurerm_resource_group.ad.name
  virtual_network_name = azurerm_virtual_network.ad_vnet.name
  address_prefixes     = ["10.0.0.128/25"]
}

# --------------------------------------------------------------------------------------------------
# Define Bastion Subnet (10.0.1.0/25)
# NOTE: Bastion requires subnet name to be exactly "AzureBastionSubnet"
# --------------------------------------------------------------------------------------------------
resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.ad.name
  virtual_network_name = azurerm_virtual_network.ad_vnet.name
  address_prefixes     = ["10.0.1.0/25"]
}

# --------------------------------------------------------------------------------------------------
# Define App Gateway Subnet (10.0.1.128/25)
# NOTE: Application Gateway requires its own dedicated subnet
# --------------------------------------------------------------------------------------------------
resource "azurerm_subnet" "app_gateway_subnet" {
  name                 = "app-gateway-subnet"
  resource_group_name  = azurerm_resource_group.ad.name
  virtual_network_name = azurerm_virtual_network.ad_vnet.name
  address_prefixes     = ["10.0.1.128/25"]
}

# --------------------------------------------------------------------------------------------------
# Define Network Security Group (NSG) for VM subnet
# --------------------------------------------------------------------------------------------------
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "vm-nsg"
  location            = azurerm_resource_group.ad.location
  resource_group_name = azurerm_resource_group.ad.name

  # Allow inbound SSH (Linux admin access)
  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow inbound RDP (Windows admin access)
  security_rule {
    name                       = "Allow-RDP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow inbound SMB (AD and file share access)
  security_rule {
    name                       = "Allow-SMB"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "445"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow inbound RStudio (RStudio IDE access)
  security_rule {
    name                       = "Allow-RStudio"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8787"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# --------------------------------------------------------------------------------------------------
# Associate NSG with VM subnet
# --------------------------------------------------------------------------------------------------
resource "azurerm_subnet_network_security_group_association" "vm_nsg_assoc" {
  subnet_id                 = azurerm_subnet.vm_subnet.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

# --------------------------------------------------------------------------------------------------
# Define a network security group for the application gateway subnet
# --------------------------------------------------------------------------------------------------

resource "azurerm_network_security_group" "rstudio_gateway_nsg" {
  name                = "rstudio-gateway-nsg"                         # Name of the NSG
  location            = azurerm_resource_group.ad.location
  resource_group_name = azurerm_resource_group.ad.name

  security_rule {
    name                       = "Allow-HTTP"                         # Rule name: Allow HTTP traffic
    priority                   = 1002                                 # Rule priority
    direction                  = "Inbound"                            # Traffic direction
    access                     = "Allow"                              # Allow or deny rule
    protocol                   = "Tcp"                                # Protocol type
    source_port_range          = "*"                                  # Source port range
    destination_port_range     = "80"                                 # Destination port
    source_address_prefix      = "*"                                  # Source address range
    destination_address_prefix = "*"                                  # Destination address range
  }

  security_rule {
    name                       = "Allow-AppGateway-Ports"             # Rule name: Allow App Gateway ports
    priority                   = 1003                                 # Rule priority
    direction                  = "Inbound"                            # Traffic direction
    access                     = "Allow"                              # Allow or deny rule
    protocol                   = "Tcp"                                # Protocol type
    source_port_range          = "*"                                  # Source port range
    destination_port_ranges    = ["65200-65535"]                      # Destination port range
    source_address_prefix      = "*"                                  # Source address range
    destination_address_prefix = "*"                                  # Destination address range
  }
}

# --------------------------------------------------------------------------------------------------
# Associate NSG with App Gateway subnet
# --------------------------------------------------------------------------------------------------
resource "azurerm_subnet_network_security_group_association" "app_gateway_nsg_assoc" {
  subnet_id                 = azurerm_subnet.app_gateway_subnet.id
  network_security_group_id = azurerm_network_security_group.rstudio_gateway_nsg.id
}
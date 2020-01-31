# Set Default Prefix
variable "prefix" {
  default = ""
}
variable "svr" {
  default = ""
}
variable "DestinationSubnet" {
  default = ""
}
variable "onprem_pip"{
  default = ""
}
variable "onprem_network" {
 default = ""
}
variable "vpntype" {
  default = "" 
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
    subscription_id = "38e7ce5f-1765-4b1a-a434-a093df9d8de8"
    client_id       = "caeb6c0d-8533-4a55-954a-13c2c428ca01"
    client_secret   = "2e58b2a1-513b-47c9-ad9f-08f32ba2ecae"
    tenant_id       = "0f70e04e-7c45-4a19-bce2-7ab09d768a09"
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "myterraformgroup" {
    name     = "${var.prefix}-${var.svr}"
    location = "eastus"

    tags = {
        environment = "${var.prefix}-${var.svr}-Test Environment"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "${var.prefix}-${var.svr}-Vnet"
    address_space       = ["172.25.0.0/16"]
    location            = "eastus"
    resource_group_name = azurerm_resource_group.myterraformgroup.name

    tags = {
        environment = "${var.prefix}-${var.svr}-Test Environment"
    }
}

# Create subnet
resource "azurerm_subnet" "FrontEndsubnet" {
    name                 = "${var.prefix}-${var.svr}-FrontEnd-Subnet"
    resource_group_name  = azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefix       = "172.25.0.0/27"
}
# Create subnet
resource "azurerm_subnet" "GatewaySubnet" {
    name                 = "GatewaySubnet"
    resource_group_name  = azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefix       = "172.25.1.0/24"
}
# Create subnet
resource "azurerm_subnet" "LANsubnet" {
    name                 = "${var.prefix}-${var.svr}-LAN-Subnet"
    resource_group_name  = azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefix       = "172.25.2.0/24"
}
# Create subnet
resource "azurerm_subnet" "Server-Networksubnet" {
    name                 = "${var.prefix}-${var.svr}-Server-Network-Subnet"
    resource_group_name  = azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefix       = "172.25.3.0/24"
}

# Create local Network Gateway
resource "azurerm_local_network_gateway" "onpremise" {
  name                = "${var.prefix}-${var.svr}-OnPrem-Gateway"
  location            = azurerm_resource_group.myterraformgroup.location
  resource_group_name = azurerm_resource_group.myterraformgroup.name
  gateway_address     = var.onprem_pip
  address_space       = ["${var.onprem_network}"]
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "${var.prefix}-${var.svr}-PublicIP"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.myterraformgroup.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "${var.prefix}-${var.svr}-Test Environment"
    }
}

# Create Virtual Network Gateway
resource "azurerm_virtual_network_gateway" "myterraformazuregateway" {
  name                = "${var.prefix}-${var.svr}-Azure_Gateway"
  location            = azurerm_resource_group.myterraformgroup.location
  resource_group_name = azurerm_resource_group.myterraformgroup.name

  type     = "Vpn"
  vpn_type = var.vpntype

  active_active = false
  enable_bgp    = false
  sku           = "Basic"

  ip_configuration {
    public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.GatewaySubnet.id
  }
}

# Create Virtual Network Gateway Connection
resource "azurerm_virtual_network_gateway_connection" "onpremise" {
  name                = "${var.prefix}-${var.svr}-VPN_Connection"
  location            = azurerm_resource_group.myterraformgroup.location
  resource_group_name = azurerm_resource_group.myterraformgroup.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.myterraformazuregateway.id
  local_network_gateway_id   = azurerm_local_network_gateway.onpremise.id

  shared_key = "4-v3ry-53cr37-5h4r3d-k3y"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "${var.prefix}-${var.svr}-NetworkSecurityGroup"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.myterraformgroup.name
    
    security_rule {
        name                       = "SSH"
        priority                   = 300
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "${var.prefix}-${var.svr}-Test Environment"
    }
}

# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
    name                      = "${var.prefix}-${var.svr}-NIC"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.myterraformgroup.name
    network_security_group_id = azurerm_network_security_group.myterraformnsg.id

    ip_configuration {
        name                          = "${var.prefix}-${var.svr}-NicConfiguration"
        subnet_id                     = azurerm_subnet.LANsubnet.id
        private_ip_address_allocation = "Dynamic"
    }

    tags = {
        environment = "${var.prefix}-${var.svr}-Test Environment"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.myterraformgroup.name
    }
    
    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.myterraformgroup.name
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "${var.prefix}-${var.svr}-Test Environment"
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "myterraformvm" {
    name                  = "${var.prefix}-${var.svr}-VM"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.myterraformgroup.name
    network_interface_ids = [azurerm_network_interface.myterraformnic.id]
    vm_size               = "Standard_F4s"

    storage_os_disk {
        name              = "${var.prefix}-${var.svr}-OsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "${var.prefix}-${var.svr}-VM"
        admin_username = "azureuser"
		admin_password = "Password1234!"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "${var.prefix}-${var.svr}-Environment"
    }
}
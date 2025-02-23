terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.75.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "codility"
  location = "uksouth"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}
resource "azurerm_subnet" "AzureBastionSubnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]

}
resource "azurerm_subnet" "app_subnet" {
  name                 = "app_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

}
resource "azurerm_subnet" "db_subnet" {
  name                 = "db_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]

}

resource "azurerm_network_interface" "app_vm_interface" {
  name                = "app_vm_interface"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_network_interface" "db_vm_interface" {
  name                = "db_vm_interface"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.db_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "app-vm" {
  name                = "app-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "adminPa$$word"
  network_interface_ids = [
    azurerm_network_interface.app_vm_interface.id,
  ]
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
   os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}
resource "azurerm_linux_virtual_machine" "db-vm" {
  name                = "db-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "adminPa$$word"
  network_interface_ids = [
    azurerm_network_interface.db_vm_interface.id,
  ]
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
   os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

resource "azurerm_public_ip" "public_ip_bastion" {
  name                = "public_ip_bastion"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku = "Standard"

}
resource "azurerm_public_ip" "public_ip_lb" {
  name                = "public_ip_lb"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku = "Standard"
}
resource "azurerm_bastion_host" "bastion" {
  name                = "bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku = "Standard"
  ip_configuration {
    name                 = "bastion_config"
    subnet_id            = azurerm_subnet.AzureBastionSubnet.id
    public_ip_address_id = azurerm_public_ip.public_ip_bastion.id
  }
}

resource "azurerm_lb" "app_lb" {
  name                = "app_lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku = "Standard"
  frontend_ip_configuration {
    name                 = "app_lb_config"
    public_ip_address_id = azurerm_public_ip.public_ip_lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "app_lb_backend_pool" {
  loadbalancer_id = azurerm_lb.app_lb.id
  name            = "app_lb_backend_pool"
}

resource "azurerm_network_interface_backend_address_pool_association" "app_lb_association" {
  network_interface_id    = azurerm_network_interface.app_vm_interface.id
  ip_configuration_name   = azurerm_network_interface.app_vm_interface.ip_configuration.name
  backend_address_pool_id = azurerm_lb_backend_address_pool.app_lb_backend_pool.id
}

resource "azurerm_lb_rule" "app_tcp_80" {
  loadbalancer_id                = azurerm_lb.app_lb.id
  name                           = "app_tcp_80"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = azurerm_lb.app_lb.frontend_ip_configuration.name
}

resource "azurerm_lb_rule" "app_tcp_443" {
  loadbalancer_id                = azurerm_lb.app_lb.id
  name                           = "app_tcp_443"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = azurerm_lb.app_lb.frontend_ip_configuration.name
}

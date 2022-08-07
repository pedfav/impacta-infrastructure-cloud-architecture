terraform {
  required_providers {
    azurerm = {
        source = "hashicorp/azurerm"
        version = ">= 3.0.1"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = true
  features {
  }
}

resource "azurerm_resource_group" "rscgrp_atv01" {
  name     = "rscgrp_atv01"
  location = "eastus"
}

resource "azurerm_virtual_network" "vnet_atv01" {
  name                = "vnet_atv01"
  location            = azurerm_resource_group.rscgrp_atv01.location
  resource_group_name = azurerm_resource_group.rscgrp_atv01.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet_atv01" {
  name                 = "subnet_atv01"
  resource_group_name  = azurerm_resource_group.rscgrp_atv01.name
  virtual_network_name = azurerm_virtual_network.vnet_atv01.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "pubip_atv01" {
  name                = "pubip_atv01"
  resource_group_name = azurerm_resource_group.rscgrp_atv01.name
  location            = azurerm_resource_group.rscgrp_atv01.location
  allocation_method   = "Static"

  tags = {
    turma = "as04"
    atividade = "01"
    disciplina = "Infrastructure and Cloud Architecture"
    professor = "João"
    aluno = "Pedro"
  }
}

resource "azurerm_network_interface" "nic_atv01" {
  name                = "nic_atv01"
  location            = azurerm_resource_group.rscgrp_atv01.location
  resource_group_name = azurerm_resource_group.rscgrp_atv01.name

  ip_configuration {
    name                            = "internal"
    subnet_id                       = azurerm_subnet.subnet_atv01.id
    private_ip_address_allocation   = "Dynamic"
    public_ip_address_id            = azurerm_public_ip.pubip_atv01.id
  }
}

resource "azurerm_network_security_group" "netsecgrp_atv01" {
  name                = "netsecgrp_atv01"
  location            = azurerm_resource_group.rscgrp_atv01.location
  resource_group_name = azurerm_resource_group.rscgrp_atv01.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Web"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "netassoc_atv01" {
  network_interface_id      = azurerm_network_interface.nic_atv01.id
  network_security_group_id = azurerm_network_security_group.netsecgrp_atv01.id
}

resource "tls_private_key" "pvtkey_atv01" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "file_pvtkey_atv01" {
  content         = tls_private_key.pvtkey_atv01.private_key_pem
  filename        = "key.pem"
  file_permission = "0600"
}

resource "azurerm_linux_virtual_machine" "vmatv01" {
  name                = "vmatv01"
  resource_group_name = azurerm_resource_group.rscgrp_atv01.name
  location            = azurerm_resource_group.rscgrp_atv01.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.nic_atv01.id
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.pvtkey_atv01.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  depends_on = [
    local_file.file_pvtkey_atv01
  ]
}

data "azurerm_public_ip" "data_pubip_atv01" {
  name = azurerm_public_ip.pubip_atv01.name
  resource_group_name = azurerm_resource_group.rscgrp_atv01.name
}

resource "null_resource" "install-nginx" {
  triggers = {
    order = azurerm_linux_virtual_machine.vmatv01.id
  }

  connection {
    type = "ssh"
    host = data.azurerm_public_ip.data_pubip_atv01.ip_address
    user = "adminuser"
    private_key = tls_private_key.pvtkey_atv01.private_key_pem
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y nginx"
    ]
  }

  depends_on = [
    azurerm_linux_virtual_machine.vmatv01
  ]
}
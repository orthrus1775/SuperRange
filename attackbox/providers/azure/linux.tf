# Ubuntu 24.04 servers for Azure provider
locals {
  ubuntu_servers = {
    "ubuntu-server-1" = {
      name               = "ubuntu-server-1"
      linux_sku          = "24_04-lts-gen2"
      linux_version      = "latest"
      private_ip_address = "{{ip_range}}.51"
      password           = "Ubuntu24.04Password!"
      size               = "Standard_B2s" # 2cpu/4G
    },
    "ubuntu-server-2" = {
      name               = "ubuntu-server-2"
      linux_sku          = "24_04-lts-gen2"
      linux_version      = "latest"
      private_ip_address = "{{ip_range}}.52"
      password           = "Ubuntu24.04Password!"
      size               = "Standard_B2s" # 2cpu/4G
    },
    "ubuntu-server-3" = {
      name               = "ubuntu-server-3"
      linux_sku          = "24_04-lts-gen2"
      linux_version      = "latest"
      private_ip_address = "{{ip_range}}.53"
      password           = "Ubuntu24.04Password!"
      size               = "Standard_B2s" # 2cpu/4G
    }
  }
}

# Create network interfaces for Ubuntu servers
resource "azurerm_network_interface" "ubuntu_nic" {
  for_each            = local.ubuntu_servers
  name                = "goad-${each.value.name}-nic"
  location            = azurerm_resource_group.goad.location
  resource_group_name = azurerm_resource_group.goad.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.private_ip_address
  }
}

# Create Ubuntu server VMs
resource "azurerm_linux_virtual_machine" "ubuntu_servers" {
  for_each              = local.ubuntu_servers
  name                  = "goad-${each.value.name}"
  location              = azurerm_resource_group.goad.location
  resource_group_name   = azurerm_resource_group.goad.name
  network_interface_ids = [azurerm_network_interface.ubuntu_nic[each.key].id]
  size                  = each.value.size

  admin_username = "ubuntu"
  admin_password = each.value.password
  
  disable_password_authentication = false

  os_disk {
    name                 = "goad-${each.value.name}-os-disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-noble"
    sku       = each.value.linux_sku
    version   = each.value.linux_version
  }

  tags = {
    Name      = "GOAD-${each.value.name}"
    Lab       = "GOAD"
    Extension = "ubuntu-servers"
  }

  custom_data = base64encode(<<-EOF
    #!/bin/bash
    hostnamectl set-hostname ${each.value.name}.{{lab_domain}}
    apt-get update
    apt-get install -y python3 python3-pip openssh-server
  EOF
  )
}

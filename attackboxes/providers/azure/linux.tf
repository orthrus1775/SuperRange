# Create attack box VMs
resource "azurerm_linux_virtual_machine" "attackboxes" {
  for_each              = local.attackboxes
  name                  = "goad-${each.value.name}"
  location              = azurerm_resource_group.goad.location
  resource_group_name   = azurerm_resource_group.goad.name
  network_interface_ids = [azurerm_network_interface.attackbox_nic[each.key].id]
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
    Extension = "attackboxes"
  }

  custom_data = base64encode(<<-EOF
    #!/bin/bash
    hostnamectl set-hostname ${each.value.name}.{{lab_domain}}
    apt-get update
    apt-get install -y python3 python3-pip openssh-server
  EOF
  )
}
# Ubuntu 24.04 servers for Proxmox provider
locals {
  ubuntu_servers = {
    "ubuntu-server-1" = {
      name   = "ubuntu-server-1"
      desc   = "ubuntu-server-1 - ubuntu 24.04 - {{ip_range}}.51"
      cores  = 2
      memory = 4096
      clone  = "Ubuntu2404_x64"
      dns    = "{{ip_range}}.1"
      ip     = "{{ip_range}}.51/24"
      gateway = "{{ip_range}}.1"
    },
    "ubuntu-server-2" = {
      name   = "ubuntu-server-2"
      desc   = "ubuntu-server-2 - ubuntu 24.04 - {{ip_range}}.52"
      cores  = 2
      memory = 4096
      clone  = "Ubuntu2404_x64"
      dns    = "{{ip_range}}.1"
      ip     = "{{ip_range}}.52/24"
      gateway = "{{ip_range}}.1"
    },
    "ubuntu-server-3" = {
      name   = "ubuntu-server-3"
      desc   = "ubuntu-server-3 - ubuntu 24.04 - {{ip_range}}.53"
      cores  = 2
      memory = 4096
      clone  = "Ubuntu2404_x64"
      dns    = "{{ip_range}}.1"
      ip     = "{{ip_range}}.53/24"
      gateway = "{{ip_range}}.1"
    }
  }
}

# Create Ubuntu server VMs for Proxmox
resource "proxmox_vm_qemu" "ubuntu_servers" {
  for_each    = local.ubuntu_servers
  name        = each.value.name
  desc        = each.value.desc
  target_node = var.pm_node
  
  clone       = each.value.clone
  full_clone  = var.pm_full_clone
  pool        = var.pm_pool
  
  cores       = each.value.cores
  memory      = each.value.memory
  
  network {
    bridge    = var.pm_network_bridge
    model     = var.pm_network_model
  }
  
  disk {
    type      = "scsi"
    storage   = var.pm_storage
    size      = "20G"
  }
  
  os_type     = "cloud-init"
  ipconfig0   = "ip=${each.value.ip},gw=${each.value.gateway}"
  nameserver  = each.value.dns
  
  sshkeys     = file("${var.ssh_keys_path}/id_rsa.pub")
  
  lifecycle {
    ignore_changes = [
      network,
      disk,
    ]
  }
}

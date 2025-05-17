
# Create attack box VMs for Proxmox
resource "proxmox_vm_qemu" "attackboxes" {
  for_each    = local.attackboxes
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
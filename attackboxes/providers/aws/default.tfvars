# Default values for Attack Boxes Extension
# Copy this file to custom.tfvars and modify as needed

# General configuration
attackbox_count      = 3
attackbox_base_name  = "attackbox"
attackbox_username   = "ubuntu"
attackbox_password   = "AttackBox2024!"
attackbox_ip_start   = 81
attackbox_ssh_port_start = 2251

# AWS specific configuration
attackbox_instance_type = "t2.medium"
attackbox_disk_size    = 20
attackbox_disk_type    = "gp3"
# Leave empty to use the latest Ubuntu 24.04 AMI
attackbox_ami_id       = ""
attackbox_ami_owner    = "099720109477" # Canonical
attackbox_ami_name_pattern = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"

# Azure specific configuration
attackbox_azure_size      = "Standard_B2s"
attackbox_azure_publisher = "Canonical"
attackbox_azure_offer     = "0001-com-ubuntu-server-noble"
attackbox_azure_sku       = "24_04-lts-gen2"
attackbox_azure_version   = "latest"

# Proxmox specific configuration
attackbox_proxmox_clone   = "Ubuntu2404_x64"
attackbox_proxmox_cores   = 2
attackbox_proxmox_memory  = 4096

# Tools to install
attackbox_additional_tools = [
  "netcat-openbsd",
  "hashcat",
  "john",
  "hydra",
  "metasploit-framework",
  "responder",
  "smbclient",
  "enum4linux",
  "nbtscan",
]

attackbox_additional_python_tools = [
  "impacket",
  "crackmapexec",
]

attackbox_git_repos = [
  {
    name = "PowerSploit"
    url  = "https://github.com/PowerShellMafia/PowerSploit.git"
  },
  {
    name = "mimikatz"
    url  = "https://github.com/gentilkiwi/mimikatz.git"
  },
  {
    name = "PEASS-ng"
    url  = "https://github.com/carlospolop/PEASS-ng.git"
  },
  {
    name = "PayloadsAllTheThings"
    url  = "https://github.com/swisskyrepo/PayloadsAllTheThings.git"
  }
]
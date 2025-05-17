# Variables for the Attack Boxes extension
# These variables allow customization of the attack boxes without changing the main code

variable "attackbox_count" {
  description = "Number of attack boxes to deploy"
  type        = number
  default     = 3
}

variable "attackbox_base_name" {
  description = "Base name for the attack boxes (will be suffixed with a number)"
  type        = string
  default     = "attackbox"
}

variable "attackbox_username" {
  description = "Username for the attack boxes"
  type        = string
  default     = "ubuntu"
}

variable "attackbox_password" {
  description = "Password for the attack boxes (used for Azure deployments)"
  type        = string
  default     = "AttackBox2024!"
  sensitive   = true
}

variable "attackbox_instance_type" {
  description = "Instance type for AWS deployment"
  type        = string
  default     = "t2.medium"
}

variable "attackbox_azure_size" {
  description = "VM size for Azure deployment"
  type        = string
  default     = "Standard_B2s"
}

variable "attackbox_disk_size" {
  description = "Root disk size in GB"
  type        = number
  default     = 20
}

variable "attackbox_disk_type" {
  description = "Root disk type for AWS"
  type        = string
  default     = "gp3"
}

variable "attackbox_ami_id" {
  description = "AMI ID for the attack boxes (AWS only, leave empty to use data source)"
  type        = string
  default     = ""
}

variable "attackbox_ami_owner" {
  description = "Owner ID for AMI lookup (AWS only)"
  type        = string
  default     = "099720109477" # Canonical
}

variable "attackbox_ami_name_pattern" {
  description = "Name pattern for AMI lookup (AWS only)"
  type        = string
  default     = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
}

variable "attackbox_azure_publisher" {
  description = "Publisher for Azure image"
  type        = string
  default     = "Canonical"
}

variable "attackbox_azure_offer" {
  description = "Offer for Azure image"
  type        = string
  default     = "0001-com-ubuntu-server-noble"
}

variable "attackbox_azure_sku" {
  description = "SKU for Azure image"
  type        = string
  default     = "24_04-lts-gen2"
}

variable "attackbox_azure_version" {
  description = "Version for Azure image"
  type        = string
  default     = "latest"
}

variable "attackbox_proxmox_clone" {
  description = "Template to clone for Proxmox"
  type        = string
  default     = "Ubuntu2404_x64"
}

variable "attackbox_proxmox_cores" {
  description = "Number of CPU cores for Proxmox VMs"
  type        = number
  default     = 2
}

variable "attackbox_proxmox_memory" {
  description = "Amount of memory in MB for Proxmox VMs"
  type        = number
  default     = 4096
}

variable "attackbox_ip_start" {
  description = "Starting last octet for IP addresses"
  type        = number
  default     = 51
}

variable "attackbox_additional_tools" {
  description = "Additional tools to install on attack boxes"
  type        = list(string)
  default     = [
    "netcat-openbsd",
    "hashcat",
    "john",
    "hydra",
    "metasploit-framework",
    "sqlmap",
    "gobuster",
    "dirb"
  ]
}

variable "attackbox_additional_python_tools" {
  description = "Additional Python tools to install on attack boxes"
  type        = list(string)
  default     = [
    "impacket",
    "bloodhound",
    "crackmapexec"
  ]
}

variable "attackbox_git_repos" {
  description = "Git repositories to clone on attack boxes"
  type        = list(object({
    name = string
    url  = string
  }))
  default     = [
    {
      name = "PowerSploit"
      url  = "https://github.com/PowerShellMafia/PowerSploit.git"
    },
    {
      name = "mimikatz"
      url  = "https://github.com/gentilkiwi/mimikatz.git"
    },
    {
      name = "BloodHound"
      url  = "https://github.com/BloodHoundAD/BloodHound.git"
    },
    {
      name = "PEASS-ng"
      url  = "https://github.com/carlospolop/PEASS-ng.git"
    }
  ]
}

variable "attackbox_ssh_port_start" {
  description = "Starting port for SSH port forwarding (VirtualBox/VMware)"
  type        = number
  default     = 2251
}
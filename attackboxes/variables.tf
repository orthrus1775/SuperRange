variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_key_pair" {
  description = "Name of the AWS key pair to use for SSH access"
  type        = string
  default     = "default"
}

variable "range_number" {
  description = "Range number for this deployment"
  type        = number
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "goad_vpc_id" {
  description = "VPC ID of the GOAD deployment"
  type        = string
}

variable "goad_subnet_id" {
  description = "Subnet ID of the GOAD deployment"
  type        = string
}

variable "goad_security_group_id" {
  description = "Security group ID of the GOAD deployment"
  type        = string
}

variable "attackbox_count" {
  description = "Number of attackboxes to create"
  type        = number
  default     = 3
}

variable "instance_type" {
  description = "EC2 instance type for attackboxes"
  type        = string
  default     = "t2.2xlarge"
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 50
}

variable "ip_start" {
  description = "Start of IP address range for attackboxes"
  type        = number
  default     = 80
}

variable "username" {
  description = "Username for the attackbox"
  type        = string
  default     = "ubuntu"
}

variable "password" {
  description = "Password for the attackbox"
  type        = string
  default     = "Password123!"
}

variable "desktop_environment" {
  description = "Desktop environment configuration"
  type = object({
    enabled = bool
    type    = string
  })
  default = {
    enabled = true
    type    = "xfce"
  }
}

variable "rdp_access" {
  description = "RDP access configuration"
  type = object({
    enabled = bool
    port    = number
  })
  default = {
    enabled = true
    port    = 3389
  }
}

variable "tools" {
  description = "List of tools to install on the attackbox"
  type        = list(string)
  default = [
    "nmap",
    "metasploit-framework",
    "wireshark",
    "burpsuite",
    "gobuster",
    "exploitdb",
    "bloodhound",
    "powershell-empire",
    "proxychains",
    "python3-pip",
    "git"
  ]
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "SuperRange"
    Environment = "Training"
  }
}
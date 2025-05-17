# Attackboxes configuration in GOAD-compatible format

locals {
  attackboxes = {
    "attackbox1" = {
      name               = "attackbox1"
      linux_sku          = "24_04-lts-gen2"  # Updated to Ubuntu 24.04
      linux_version      = "latest"
      ami                = data.aws_ami.ubuntu.id  # Dynamic AMI lookup instead of hardcoded value
      private_ip_address = "{{ip_range}}.80"
      password           = "Password123!"
      size               = "t2.2xlarge"
    },
    "attackbox2" = {
      name               = "attackbox2"  # Fixed name (was duplicate)
      linux_sku          = "24_04-lts-gen2"
      linux_version      = "latest"
      ami                = data.aws_ami.ubuntu.id
      private_ip_address = "{{ip_range}}.81"
      password           = "Password123!"
      size               = "t2.2xlarge"
    },
    "attackbox3" = {
      name               = "attackbox3"  # Fixed name (was duplicate)
      linux_sku          = "24_04-lts-gen2"
      linux_version      = "latest"
      ami                = data.aws_ami.ubuntu.id
      private_ip_address = "{{ip_range}}.82"
      password           = "Password123!"
      size               = "t2.2xlarge"
    }
  }
}

# Find the latest Ubuntu 24.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
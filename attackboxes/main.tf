terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}

# Get the latest Ubuntu 24.04 AMI
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

# User data script to install tools and configure the attackbox
locals {
  user_data = <<-EOF
#!/bin/bash

# Update and install base packages
apt-get update
apt-get upgrade -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# Setup for attackbox tools
apt-get install -y ${join(" ", var.tools)}

# Setup desktop environment if enabled
if [ "${var.desktop_environment.enabled}" = "true" ]; then
  # Install desktop environment
  if [ "${var.desktop_environment.type}" = "xfce" ]; then
    apt-get install -y xfce4 xfce4-goodies
  elif [ "${var.desktop_environment.type}" = "gnome" ]; then
    apt-get install -y ubuntu-desktop
  elif [ "${var.desktop_environment.type}" = "kde" ]; then
    apt-get install -y kubuntu-desktop
  fi

  # Install RDP server if enabled
  if [ "${var.rdp_access.enabled}" = "true" ]; then
    apt-get install -y xrdp
    systemctl enable xrdp
    systemctl start xrdp
    
    # Configure xrdp to use selected desktop environment
    if [ "${var.desktop_environment.type}" = "xfce" ]; then
      echo "xfce4-session" > /home/ubuntu/.xsession
      chown ubuntu:ubuntu /home/ubuntu/.xsession
      chmod +x /home/ubuntu/.xsession
    fi
    
    # Configure firewall for RDP if ufw is active
    ufw allow ${var.rdp_access.port}/tcp
  fi
fi

# Set password for ubuntu user
echo "ubuntu:${var.password}" | chpasswd

# Network configuration to connect to GOAD network
cat > /etc/netplan/99-goad-connection.yaml <<EOL
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      routes:
        - to: 192.168.${var.range_number}.0/24
          via: $(ip route | grep default | awk '{print $3}')
EOL

netplan apply

# Add GOAD servers to /etc/hosts
cat >> /etc/hosts <<EOL
192.168.${var.range_number}.10 kingslanding dc1 kingslanding.sevenkingdoms.local
192.168.${var.range_number}.11 winterfell dc2 winterfell.north.sevenkingdoms.local
192.168.${var.range_number}.12 castelblack srv castelblack.north.sevenkingdoms.local
192.168.${var.range_number}.31 desktop ws01 desktop.sevenkingdoms.local
EOL

# Install additional tools and scripts
mkdir -p /opt/tools

# Clone some useful repositories
git clone https://github.com/SecureAuthCorp/impacket.git /opt/tools/impacket
cd /opt/tools/impacket && pip3 install -r requirements.txt && pip3 install .

git clone https://github.com/BloodHoundAD/BloodHound.git /opt/tools/BloodHound

# Setup BloodHound dependencies
apt-get install -y libgconf-2-4 neo4j python3-pip
pip3 install bloodhound

# Allow custom scripts to run at first boot
chmod +x /opt/tools/scripts/*.sh
/opt/tools/scripts/first-boot.sh

# Final system update
apt-get update
apt-get upgrade -y
apt-get autoremove -y
apt-get clean

# Signal completion
touch /etc/attackbox-setup-complete
EOF
}

# Create attackboxes security group
resource "aws_security_group" "attackbox_sg" {
  name        = "attackbox-sg-range${var.range_number}"
  description = "Security group for attackboxes in range ${var.range_number}"
  vpc_id      = var.goad_vpc_id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # RDP access if enabled
  dynamic "ingress" {
    for_each = var.rdp_access.enabled ? [1] : []
    content {
      from_port   = var.rdp_access.port
      to_port     = var.rdp_access.port
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "attackbox-sg-range${var.range_number}"
  })
}

# Create a VPC peering connection to GOAD VPC
resource "aws_vpc_peering_connection" "goad_peering" {
  vpc_id      = aws_vpc.attackbox_vpc.id
  peer_vpc_id = var.goad_vpc_id
  auto_accept = true

  tags = merge(var.tags, {
    Name = "attackbox-goad-peering-range${var.range_number}"
  })
}

# Create a VPC for attackboxes
resource "aws_vpc" "attackbox_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "attackbox-vpc-range${var.range_number}"
  })
}

# Create a subnet in the VPC
resource "aws_subnet" "attackbox_subnet" {
  vpc_id                  = aws_vpc.attackbox_vpc.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = merge(var.tags, {
    Name = "attackbox-subnet-range${var.range_number}"
  })
}

# Create an internet gateway
resource "aws_internet_gateway" "attackbox_igw" {
  vpc_id = aws_vpc.attackbox_vpc.id

  tags = merge(var.tags, {
    Name = "attackbox-igw-range${var.range_number}"
  })
}

# Create a route table
resource "aws_route_table" "attackbox_rt" {
  vpc_id = aws_vpc.attackbox_vpc.id

  # Route to the internet gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.attackbox_igw.id
  }

  # Route to the GOAD VPC
  route {
    cidr_block                = "192.168.${var.range_number}.0/24"
    vpc_peering_connection_id = aws_vpc_peering_connection.goad_peering.id
  }

  tags = merge(var.tags, {
    Name = "attackbox-rt-range${var.range_number}"
  })
}

# Associate the route table with the subnet
resource "aws_route_table_association" "attackbox_rt_assoc" {
  subnet_id      = aws_subnet.attackbox_subnet.id
  route_table_id = aws_route_table.attackbox_rt.id
}

# Update GOAD's route table to route to attackbox VPC
resource "aws_route" "goad_to_attackbox" {
  route_table_id            = data.aws_route_table.goad_rt.id
  destination_cidr_block    = var.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.goad_peering.id
}

# Get GOAD's route table
data "aws_route_table" "goad_rt" {
  vpc_id = var.goad_vpc_id
}

# Create attackboxes
resource "aws_instance" "attackbox" {
  count         = var.attackbox_count
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.attackbox_subnet.id
  key_name      = var.aws_key_pair

  vpc_security_group_ids = [
    aws_security_group.attackbox_sg.id
  ]

  private_ip = "10.${var.range_number}.1.${var.ip_start + count.index}"

  user_data = local.user_data

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  tags = merge(var.tags, {
    Name = "attackbox-${count.index + 1}-range${var.range_number}"
  })
}

# Output the IPs of the attackboxes
output "attackboxes_ips" {
  value = aws_instance.attackbox[*].private_ip
}

output "attackboxes_public_ips" {
  value = aws_instance.attackbox[*].public_ip
}
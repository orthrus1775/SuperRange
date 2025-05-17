# Attack Boxes for GOAD AWS Extension

# Define the attack box configurations
locals {
  attackboxes = {
    for i in range(1, var.attackbox_count + 1) : 
    "${var.attackbox_base_name}-${i}" => {
      name               = "${var.attackbox_base_name}-${i}"
      ami                = var.attackbox_ami_id != "" ? var.attackbox_ami_id : data.aws_ami.ubuntu_24_04[0].id
      instance_type      = var.attackbox_instance_type
      private_ip_address = "${local.ip_prefix}.${var.attackbox_ip_start + i - 1}"
    }
  }
}

# Data source to get the latest Ubuntu 24.04 AMI if no specific AMI ID is provided
data "aws_ami" "ubuntu_24_04" {
  count       = var.attackbox_ami_id == "" ? 1 : 0
  most_recent = true
  owners      = [var.attackbox_ami_owner]

  filter {
    name   = "name"
    values = [var.attackbox_ami_name_pattern]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create the attack box instances
resource "aws_instance" "attackboxes" {
  for_each = local.attackboxes

  ami                    = each.value.ami
  instance_type          = each.value.instance_type
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  private_ip             = each.value.private_ip_address
  key_name               = "GOAD-linux-keypair"

  root_block_device {
    volume_size = var.attackbox_disk_size
    volume_type = var.attackbox_disk_type
    tags = {
      Name = "GOAD-${each.value.name}-root"
      Lab  = "GOAD"
    }
  }

  # Cloud-init script to set up the attack box for Ansible provisioning
  user_data = <<-EOF
    #!/bin/bash
    hostnamectl set-hostname ${each.value.name}.{{lab_domain}}
    apt-get update
    apt-get install -y python3 python3-pip openssh-server
    echo "${var.attackbox_username} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${var.attackbox_username}
    chmod 440 /etc/sudoers.d/${var.attackbox_username}
    mkdir -p /home/${var.attackbox_username}/.ssh
    echo "${tls_private_key.linux.public_key_openssh}" > /home/${var.attackbox_username}/.ssh/authorized_keys
    chown -R ${var.attackbox_username}:${var.attackbox_username} /home/${var.attackbox_username}/.ssh
    chmod 700 /home/${var.attackbox_username}/.ssh
    chmod 600 /home/${var.attackbox_username}/.ssh/authorized_keys
  EOF

  tags = {
    Name = "GOAD-${each.value.name}"
    Lab  = "GOAD"
    Extension = "attackboxes"
  }
}
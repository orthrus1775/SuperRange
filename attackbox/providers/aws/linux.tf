# Ubuntu 24.04 Servers for GOAD AWS Extension

# Define the Ubuntu server configurations
locals {
  ubuntu_servers = {
    "ubuntu-server-1" = {
      name               = "ubuntu-server-1"
      ami                = "ami-00c71bd4d220aa22a" # Replace with appropriate Ubuntu 24.04 AMI for your region
      instance_type      = "t2.medium"
      private_ip_address = "{{ip_range}}.51"
    },
    "ubuntu-server-2" = {
      name               = "ubuntu-server-2"
      ami                = "ami-00c71bd4d220aa22a" # Replace with appropriate Ubuntu 24.04 AMI for your region
      instance_type      = "t2.medium"
      private_ip_address = "{{ip_range}}.52"
    },
    "ubuntu-server-3" = {
      name               = "ubuntu-server-3"
      ami                = "ami-00c71bd4d220aa22a" # Replace with appropriate Ubuntu 24.04 AMI for your region
      instance_type      = "t2.medium"
      private_ip_address = "{{ip_range}}.53"
    }
  }
}

# Create the Ubuntu server instances
resource "aws_instance" "ubuntu_servers" {
  for_each = local.ubuntu_servers

  ami                    = each.value.ami
  instance_type          = each.value.instance_type
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  private_ip             = each.value.private_ip_address
  key_name               = "GOAD-linux-keypair"

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    tags = {
      Name = "GOAD-${each.value.name}-root"
      Lab  = "GOAD"
    }
  }

  # Cloud-init script to set up the server for Ansible provisioning
  user_data = <<-EOF
    #!/bin/bash
    hostnamectl set-hostname ${each.value.name}.{{lab_domain}}
    apt-get update
    apt-get install -y python3 python3-pip openssh-server
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu
    chmod 440 /etc/sudoers.d/ubuntu
    mkdir -p /home/ubuntu/.ssh
    echo "${tls_private_key.linux.public_key_openssh}" > /home/ubuntu/.ssh/authorized_keys
    chown -R ubuntu:ubuntu /home/ubuntu/.ssh
    chmod 700 /home/ubuntu/.ssh
    chmod 600 /home/ubuntu/.ssh/authorized_keys
  EOF

  tags = {
    Name = "GOAD-${each.value.name}"
    Lab  = "GOAD"
    Extension = "ubuntu-servers"
  }
}

# Create an additional security group rule to allow communication between servers
resource "aws_security_group_rule" "ubuntu_internal_communication" {
  security_group_id = aws_security_group.private_sg.id
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  self              = true
  description       = "Allow all TCP traffic between Ubuntu servers"
}

# Create key pair for the Ubuntu servers
resource "tls_private_key" "linux" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "linux_keypair" {
  key_name   = "GOAD-linux-keypair"
  public_key = tls_private_key.linux.public_key_openssh

  provisioner "local-exec" {
    command = "echo '${tls_private_key.linux.private_key_pem}' > ../ssh_keys/id_rsa_linux && echo '${tls_private_key.linux.public_key_openssh}' > ../ssh_keys/id_rsa_linux.pub && chmod 600 ../ssh_keys/id_rsa_linux*"
  }
}

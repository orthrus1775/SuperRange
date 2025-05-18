# Create network interfaces for attackboxes
resource "aws_network_interface" "goad-vm-nic-attackbox-1" {
  subnet_id   = aws_subnet.goad_public_network.id
  private_ips = ["{{ip_range}}.50"]
  security_groups = [aws_security_group.goad_security_group.id]
  tags = {
    Lab = "{{lab_identifier}}"
  }
}

resource "aws_network_interface" "goad-vm-nic-attackbox-2" {
  subnet_id   = aws_subnet.goad_public_network.id
  private_ips = ["{{ip_range}}.51"]
  security_groups = [aws_security_group.goad_security_group.id]
  tags = {
    Lab = "{{lab_identifier}}"
  }
}

resource "aws_network_interface" "goad-vm-nic-attackbox-3" {
  subnet_id   = aws_subnet.goad_public_network.id
  private_ips = ["{{ip_range}}.52"]
  security_groups = [aws_security_group.goad_security_group.id]
  tags = {
    Lab = "{{lab_identifier}}"
  }
}

# Create attackbox instances
resource "aws_instance" "goad-vm-attackbox-1" {
  ami           = "ami-0158cbc3c8e9ef377"
  instance_type = "t2.2xlarge"
  network_interface {
    network_interface_id = aws_network_interface.goad-vm-nic-attackbox-1.id
    device_index = 0
  }
  user_data = templatefile("${path.module}/jumpbox-init.sh.tpl", {
                                username = var.jumpbox_username
                           })
  key_name = "{{lab_identifier}}-linux-keypair"
  tags = {
    Name = "attackbox-1"
    Lab = "{{lab_identifier}}"
  }
  root_block_device {
    volume_size = 60
    tags = {
      Name = "attackbox-1-root"
      Lab = "{{lab_identifier}}"
    }
  }
}

resource "aws_instance" "goad-vm-attackbox-2" {
  ami           = "ami-0158cbc3c8e9ef377"
  instance_type = "t2.2xlarge"
  network_interface {
    network_interface_id = aws_network_interface.goad-vm-nic-attackbox-2.id
    device_index = 0
  }
  user_data = templatefile("${path.module}/jumpbox-init.sh.tpl", {
                                username = var.jumpbox_username
                           })
  key_name = "{{lab_identifier}}-linux-keypair"
  tags = {
    Name = "attackbox-2"
    Lab = "{{lab_identifier}}"
  }
  root_block_device {
    volume_size = 60
    tags = {
      Name = "attackbox-2-root"
      Lab = "{{lab_identifier}}"
    }
  }
}

resource "aws_instance" "goad-vm-attackbox-3" {
  ami           = "ami-0158cbc3c8e9ef377"
  instance_type = "t2.2xlarge"
  network_interface {
    network_interface_id = aws_network_interface.goad-vm-nic-attackbox-3.id
    device_index = 0
  }
  user_data = templatefile("${path.module}/jumpbox-init.sh.tpl", {
                                username = var.jumpbox_username
                           })
  key_name = "{{lab_identifier}}-linux-keypair"
  tags = {
    Name = "attackbox-3"
    Lab = "{{lab_identifier}}"
  }
  root_block_device {
    volume_size = 60
    tags = {
      Name = "attackbox-3-root"
      Lab = "{{lab_identifier}}"
    }
  }
}
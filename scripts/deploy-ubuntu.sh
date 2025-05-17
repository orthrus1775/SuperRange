
#!/bin/bash
# deploy-ubuntu.sh - Deploy Ubuntu servers for a specific range

set -e # Exit on any error

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <range-id> <base-dir>"
    exit 1
fi

RANGE_ID=$1
BASE_DIR=$2
RANGE_DIR="${BASE_DIR}/${RANGE_ID}"
UBUNTU_DIR="${RANGE_DIR}/ubuntu-servers"
CONFIG_FILE="${RANGE_DIR}/range-config.json"
GOAD_SUMMARY="${RANGE_DIR}/goad-summary.txt"

# Check if configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Check if GOAD deployment is complete
if [ ! -f "$GOAD_SUMMARY" ]; then
    echo "GOAD deployment information not found. Please deploy GOAD first."
    exit 1
fi

# Load configuration
RANGE_NUM=$(jq -r '.range_number' "$CONFIG_FILE")
AWS_REGION=$(jq -r '.aws_region' "$CONFIG_FILE")
AWS_AZ=$(jq -r '.aws_availability_zone' "$CONFIG_FILE")
KEY_NAME=$(jq -r '.key_name' "$CONFIG_FILE")
UBUNTU_SUBNET=$(jq -r '.ubuntu_subnet' "$CONFIG_FILE")
GOAD_CIDR=$(jq -r '.goad_cidr' "$CONFIG_FILE")
ENABLE_DESKTOP=$(jq -r '.enable_desktop' "$CONFIG_FILE")
INSTALL_RDP=$(jq -r '.install_rdp' "$CONFIG_FILE")

echo "Deploying Ubuntu servers for range: $RANGE_ID (Range #$RANGE_NUM)"
echo "- AWS Region: $AWS_REGION"
echo "- AWS AZ: $AWS_AZ"
echo "- Ubuntu Subnet: $UBUNTU_SUBNET"
echo "- GOAD CIDR: $GOAD_CIDR"
echo "- Key Name: $KEY_NAME"
echo "- Desktop Environment: $([ "$ENABLE_DESKTOP" == "true" ] && echo "Enabled" || echo "Disabled")"
echo "- RDP Access: $([ "$INSTALL_RDP" == "true" ] && echo "Enabled" || echo "Disabled")"

# Create Ubuntu servers directory
mkdir -p "$UBUNTU_DIR"

# Create Terraform files for Ubuntu servers
echo "Creating Terraform configuration..."

# Create variables.tf
cat > "${UBUNTU_DIR}/variables.tf" <<EOF
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "${AWS_REGION}"
}

variable "aws_availability_zone" {
  description = "AWS availability zone to deploy resources"
  type        = string
  default     = "${AWS_AZ}"
}

variable "range_id" {
  description = "Identifier for this range"
  type        = string
  default     = "${RANGE_ID}"
}

variable "range_number" {
  description = "Numeric identifier for this range"
  type        = number
  default     = ${RANGE_NUM}
}

variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 3
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.2xlarge"
}

variable "key_name" {
  description = "Name of the SSH key pair to use for instances"
  type        = string
  default     = "${KEY_NAME}"
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 50
}

variable "ip_range" {
  description = "First three octets of the IP range for GOAD-Light"
  type        = string
  default     = "192.168.${RANGE_NUM}"
}

variable "ubuntu_ips" {
  description = "List of IPs for Ubuntu instances"
  type        = list(string)
  default     = [
    "${jq -r '.ubuntu_ips[0]' "$CONFIG_FILE"}",
    "${jq -r '.ubuntu_ips[1]' "$CONFIG_FILE"}",
    "${jq -r '.ubuntu_ips[2]' "$CONFIG_FILE"}"
  ]
}

variable "ubuntu_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.${RANGE_NUM}.0.0/16"
}

variable "ubuntu_subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "${UBUNTU_SUBNET}"
}

variable "goad_cidr" {
  description = "CIDR block for GOAD-Light network"
  type        = string
  default     = "${GOAD_CIDR}"
}

variable "enable_desktop" {
  description = "Whether to install desktop environment"
  type        = bool
  default     = ${ENABLE_DESKTOP}
}

variable "install_rdp" {
  description = "Whether to install RDP server"
  type        = bool
  default     = ${INSTALL_RDP}
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {
    Name        = "${RANGE_ID}-ubuntu"
    Environment = "GOAD-Lab"
    RangeID     = "${RANGE_ID}"
    Project     = "GOAD-Multi-Range"
  }
}
EOF

# Create main.tf
cat > "${UBUNTU_DIR}/main.tf" <<EOF
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

resource "aws_vpc" "ubuntu_vpc" {
  cidr_block           = var.ubuntu_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.tags,
    {
      Name = "\${var.range_id}-ubuntu-vpc"
    }
  )
}

resource "aws_internet_gateway" "ubuntu_igw" {
  vpc_id = aws_vpc.ubuntu_vpc.id

  tags = merge(
    var.tags,
    {
      Name = "\${var.range_id}-ubuntu-igw"
    }
  )
}

resource "aws_subnet" "ubuntu_subnet" {
  vpc_id                  = aws_vpc.ubuntu_vpc.id
  cidr_block              = var.ubuntu_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = var.aws_availability_zone

  tags = merge(
    var.tags,
    {
      Name = "\${var.range_id}-ubuntu-subnet"
    }
  )
}

resource "aws_route_table" "ubuntu_rt" {
  vpc_id = aws_vpc.ubuntu_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ubuntu_igw.id
  }

  # Add route to GOAD network if VPC peering is set up
  route {
    cidr_block = var.goad_cidr
    gateway_id = aws_internet_gateway.ubuntu_igw.id
  }

  tags = merge(
    var.tags,
    {
      Name = "\${var.range_id}-ubuntu-rt"
    }
  )
}

resource "aws_route_table_association" "ubuntu_rta" {
  subnet_id      = aws_subnet.ubuntu_subnet.id
  route_table_id = aws_route_table.ubuntu_rt.id
}

resource "aws_security_group" "ubuntu_sg" {
  name        = "\${var.range_id}-ubuntu-sg"
  description = "Security group for Ubuntu instances in range \${var.range_id}"
  vpc_id      = aws_vpc.ubuntu_vpc.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # RDP access
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "RDP access"
  }

  # Web access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  # All internal traffic within the VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.ubuntu_cidr, var.goad_cidr]
    description = "All internal traffic"
  }

  # All AD related ports
  # Kerberos
  ingress {
    from_port   = 88
    to_port     = 88
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Kerberos"
  }
  
  ingress {
    from_port   = 88
    to_port     = 88
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Kerberos UDP"
  }

  # LDAP
  ingress {
    from_port   = 389
    to_port     = 389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "LDAP"
  }
  
  ingress {
    from_port   = 389
    to_port     = 389
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "LDAP UDP"
  }

  # LDAPS
  ingress {
    from_port   = 636
    to_port     = 636
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "LDAPS"
  }

  # SMB/CIFS
  ingress {
    from_port   = 445
    to_port     = 445
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SMB"
  }
  
  ingress {
    from_port   = 137
    to_port     = 139
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "NetBIOS"
  }
  
  ingress {
    from_port   = 137
    to_port     = 139
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "NetBIOS UDP"
  }

  # DNS
  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS TCP"
  }
  
  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS UDP"
  }

  # ICMP (Ping)
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "ICMP"
  }

  # Outbound - allow all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name = "\${var.range_id}-ubuntu-sg"
    }
  )
}

resource "aws_instance" "ubuntu" {
  count                       = var.instance_count
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.ubuntu_sg.id]
  subnet_id                   = aws_subnet.ubuntu_subnet.id
  associate_public_ip_address = true
  availability_zone           = var.aws_availability_zone
  
  # Derive private IP from subnet CIDR
  private_ip = "\${var.ubuntu_ips[count.index]}"

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              export DEBIAN_FRONTEND=noninteractive
              
              # Update and install basic packages
              apt-get update && apt-get upgrade -y
              apt-get install -y vim git curl wget python3-venv python3-pip nmap ldap-utils smbclient winbind krb5-user net-tools

              # Set hostname based on instance number
              hostnamectl set-hostname ${var.range_id}-ubuntu-\$((\${count.index} + 1))
              
              # Add hosts entries for the GOAD environment
              echo "${var.ip_range}.10 kingslanding.sevenkingdoms.local kingslanding" >> /etc/hosts
              echo "${var.ip_range}.11 winterfell.north.sevenkingdoms.local winterfell" >> /etc/hosts
              echo "${var.ip_range}.22 castelblack.north.sevenkingdoms.local castelblack" >> /etc/hosts
              echo "${var.ip_range}.31 desktop.sevenkingdoms.local desktop" >> /etc/hosts
              
              # Add host entries for the Ubuntu instances
              echo "${var.ubuntu_ips[0]} ${var.range_id}-ubuntu-1" >> /etc/hosts
              echo "${var.ubuntu_ips[1]} ${var.range_id}-ubuntu-2" >> /etc/hosts
              echo "${var.ubuntu_ips[2]} ${var.range_id}-ubuntu-3" >> /etc/hosts
              
              # Configure Kerberos for AD authentication
              cat > /etc/krb5.conf << 'EOK'
              [libdefaults]
                  default_realm = SEVENKINGDOMS.LOCAL
                  dns_lookup_realm = false
                  dns_lookup_kdc = false
                  ticket_lifetime = 24h
                  renew_lifetime = 7d
                  forwardable = true

              [realms]
                  SEVENKINGDOMS.LOCAL = {
                      kdc = kingslanding.sevenkingdoms.local
                      admin_server = kingslanding.sevenkingdoms.local
                      default_domain = sevenkingdoms.local
                  }
                  NORTH.SEVENKINGDOMS.LOCAL = {
                      kdc = winterfell.north.sevenkingdoms.local
                      admin_server = winterfell.north.sevenkingdoms.local
                      default_domain = north.sevenkingdoms.local
                  }

              [domain_realm]
                  .sevenkingdoms.local = SEVENKINGDOMS.LOCAL
                  sevenkingdoms.local = SEVENKINGDOMS.LOCAL
                  .north.sevenkingdoms.local = NORTH.SEVENKINGDOMS.LOCAL
                  north.sevenkingdoms.local = NORTH.SEVENKINGDOMS.LOCAL
              EOK
              
              # Install Python-based AD tools
              pip3 install impacket crackmapexec bloodhound enum4linux-ng

              %{if var.enable_desktop}
              # Install desktop environment
              echo "Installing desktop environment..."
              apt-get install -y ubuntu-desktop

              # Configure automatic login for ubuntu user
              mkdir -p /etc/gdm3
              cat > /etc/gdm3/custom.conf << 'EOD'
              [daemon]
              AutomaticLoginEnable=true
              AutomaticLogin=ubuntu
              EOD
              %{endif}

              %{if var.install_rdp}
              # Install RDP server
              echo "Installing RDP server..."
              apt-get install -y xrdp
              systemctl enable xrdp
              systemctl start xrdp
              
              # Configure firewall for RDP
              ufw allow 3389/tcp
              
              # Fix black screen issue
              sed -i 's/^test -x \/etc\/X11\/Xsession/# &/' /etc/xrdp/startwm.sh
              
              # Set RDP password for ubuntu user
              echo "ubuntu:Password123!" | chpasswd
              %{endif}

              # Create a connectivity test script
              cat > /home/ubuntu/check-goad-connectivity.sh << 'EOC'
              #!/bin/bash

              # Quick script to test connectivity to GOAD-Light environment

              echo "=== GOAD-Light Connectivity Test ==="
              echo ""

              # Check ping
              echo "Testing ping connectivity:"
              for HOST in ${var.ip_range}.10 ${var.ip_range}.11 ${var.ip_range}.22 ${var.ip_range}.31; do
                echo -n "  $HOST: "
                ping -c 1 -W 2 $HOST > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                  echo "Reachable"
                else
                  echo "Unreachable"
                fi
              done

              echo ""
              echo "Testing DNS resolution:"
              for NAME in kingslanding.sevenkingdoms.local winterfell.north.sevenkingdoms.local castelblack.north.sevenkingdoms.local desktop.sevenkingdoms.local; do
                echo -n "  $NAME: "
                host $NAME > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                  echo "Resolves"
                else
                  echo "Does not resolve (using hosts file instead)"
                fi
              done

              echo ""
              echo "Testing Active Directory Services:"

              echo -n "  SMB on kingslanding: "
              smbclient -L //kingslanding.sevenkingdoms.local -U '%' -N > /dev/null 2>&1
              if [ $? -eq 0 ]; then
                echo "Available"
              else
                echo "Unavailable"
              fi

              echo -n "  LDAP on kingslanding: "
              ldapsearch -x -h kingslanding.sevenkingdoms.local -b "" -s base > /dev/null 2>&1
              if [ $? -eq 0 ]; then
                echo "Available"
              else
                echo "Unavailable"
              fi

              echo -n "  Kerberos on kingslanding: "
              echo "Password123!" | kinit Administrator@SEVENKINGDOMS.LOCAL > /dev/null 2>&1
              if [ $? -eq 0 ]; then
                echo "Available"
                kdestroy
              else
                echo "Unavailable"
              fi

              echo ""
              echo "=== Connectivity Test Complete ==="
              EOC

              chmod +x /home/ubuntu/check-goad-connectivity.sh
              chown ubuntu:ubuntu /home/ubuntu/check-goad-connectivity.sh
              
              # Add helpful aliases for GOAD interaction to ubuntu user's .bashrc
              cat >> /home/ubuntu/.bashrc << 'EOB'

              # GOAD-Light helper commands
              alias enum-sevenkingdoms="crackmapexec smb kingslanding.sevenkingdoms.local --users"
              alias enum-north="crackmapexec smb winterfell.north.sevenkingdoms.local --users"
              alias rdp-kingslanding="xfreerdp /u:Administrator /p:'Password123!' /v:${var.ip_range}.10"
              alias rdp-winterfell="xfreerdp /u:Administrator /p:'Password123!' /v:${var.ip_range}.11"
              alias rdp-castelblack="xfreerdp /u:Administrator /p:'Password123!' /v:${var.ip_range}.22"
              alias rdp-desktop="xfreerdp /u:Administrator /p:'Password123!' /v:${var.ip_range}.31"

              # Function to get a Kerberos ticket
              get-ticket() {
                local USER=$1
                local PASS=$2
                local DOMAIN=$3
                
                if [ -z "$DOMAIN" ]; then
                  DOMAIN="sevenkingdoms.local"
                fi
                
                echo "$PASS" | kinit "${USER}@${DOMAIN^^}"
                klist
              }

              # Function to test connectivity to GOAD environment
              check-goad() {
                echo "Testing GOAD-Light connectivity:"
                
                echo -n "kingslanding (${var.ip_range}.10): "
                ping -c 1 -W 1 ${var.ip_range}.10 > /dev/null && echo "✓" || echo "✗" 
                
                echo -n "winterfell (${var.ip_range}.11): "
                ping -c 1 -W 1 ${var.ip_range}.11 > /dev/null && echo "✓" || echo "✗"
                
                echo -n "castelblack (${var.ip_range}.22): "
                ping -c 1 -W 1 ${var.ip_range}.22 > /dev/null && echo "✓" || echo "✗"
                
                echo -n "desktop (${var.ip_range}.31): "
                ping -c 1 -W 1 ${var.ip_range}.31 > /dev/null && echo "✓" || echo "✗"
                
                echo ""
                echo "LDAP Connectivity:"
                ldapsearch -x -h kingslanding.sevenkingdoms.local -b "" -s base > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                  echo "LDAP on kingslanding: ✓"
                else
                  echo "LDAP on kingslanding: ✗"
                fi
                
                echo ""
                echo "SMB Connectivity:"
                smbclient -L //kingslanding.sevenkingdoms.local -U '%' -N > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                  echo "SMB on kingslanding: ✓"
                else
                  echo "SMB on kingslanding: ✗"
                fi
              }
              EOB
              
              # Configure network for proper routing to GOAD-Light network
              cat > /etc/netplan/60-goad-routes.yaml << EON
              network:
                version: 2
                ethernets:
                  eth0:
                    routes:
                      - to: ${var.goad_cidr}
                        scope: link
              EON
              
              # Apply the network configuration
              netplan apply
              
              # Enable IP forwarding for connectivity
              echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
              sysctl -p
              
              # Create a welcome message with instructions
              cat > /etc/motd << EOM
              ==============================================================
                Welcome to ${var.range_id} Ubuntu Server #\$((\${count.index} + 1))
              ==============================================================

              This server is pre-configured to communicate with GOAD-Light environment.
              IP Address: ${var.ubuntu_ips[count.index]}

              GOAD-Light domains:
                - sevenkingdoms.local (DC: kingslanding - ${var.ip_range}.10)
                - north.sevenkingdoms.local (DC: winterfell - ${var.ip_range}.11, Server: castelblack - ${var.ip_range}.22)
                - Workstation: desktop.sevenkingdoms.local (${var.ip_range}.50)

              Quick commands:
                - check-goad           : Test connectivity to GOAD-Light
                - rdp-kingslanding     : RDP to the main domain controller
                - enum-sevenkingdoms   : Enumerate users in the main domain

              Desktop & RDP Access:
                - Desktop Environment: $([ "${ENABLE_DESKTOP}" == "true" ] && echo "Enabled" || echo "Disabled")
                - RDP Access: $([ "${INSTALL_RDP}" == "true" ] && echo "Enabled (Username: ubuntu, Password: Password123!)" || echo "Disabled")

              To test connectivity, run:
                ./check-goad-connectivity.sh

              Happy hacking!
              ==============================================================
              EOM

              # Install additional tools for AD interaction
              apt-get install -y enum4linux nbtscan fping dnsutils wireshark-cli
              apt-get install -y xfreerdp
              EOF

  tags = merge(
    var.tags,
    {
      Name = "\${var.range_id}-ubuntu-\${count.index + 1}"
    }
  )
}

resource "aws_eip" "ubuntu" {
  count    = var.instance_count
  instance = aws_instance.ubuntu[count.index].id
  domain   = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "\${var.range_id}-ubuntu-eip-\${count.index + 1}"
    }
  )
}
EOF

# Create outputs.tf
cat > "${UBUNTU_DIR}/outputs.tf" <<EOF
output "instance_ids" {
  description = "IDs of the created EC2 instances"
  value       = aws_instance.ubuntu[*].id
}

output "public_ips" {
  description = "Public IP addresses of the instances"
  value       = aws_eip.ubuntu[*].public_ip
}

output "private_ips" {
  description = "Private IP addresses of the instances"
  value       = aws_instance.ubuntu[*].private_ip
}

output "public_dns" {
  description = "Public DNS names of the instances"
  value       = aws_instance.ubuntu[*].public_dns
}

output "ssh_commands" {
  description = "SSH commands to connect to the instances"
  value = [
    for i in range(var.instance_count) :
    "ssh -i ~/.ssh/\${var.key_name}.pem ubuntu@\${aws_eip.ubuntu[i].public_ip}"
  ]
}

output "rdp_commands" {
  description = "RDP information for the instances"
  value = [
    for i in range(var.instance_count) :
    "Server: \${aws_eip.ubuntu[i].public_ip}, Username: ubuntu, Password: Password123!"
  ]
}

output "range_id" {
  description = "Range identifier"
  value       = var.range_id
}

output "range_number" {
  description = "Range number"
  value       = var.range_number
}

output "goad_cidr" {
  description = "GOAD-Light CIDR block"
  value       = var.goad_cidr
}

output "ubuntu_subnet_cidr" {
  description = "Ubuntu subnet CIDR block"
  value       = var.ubuntu_subnet_cidr
}
EOF

# Navigate to Ubuntu servers directory
cd "$UBUNTU_DIR"

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Create a plan
echo "Creating Terraform plan..."
terraform plan -out=ubuntu.tfplan

# Apply the plan
echo "Deploying Ubuntu servers (this may take 10-15 minutes)..."
echo "Starting deployment at: $(date)"

# Create a log file
LOGFILE="${RANGE_DIR}/ubuntu-deployment.log"
touch "$LOGFILE"

# Run Terraform apply
terraform apply -auto-approve ubuntu.tfplan | tee -a "$LOGFILE"

# Check if deployment was successful
if [ $? -eq 0 ]; then
    echo "Ubuntu servers deployment completed successfully at: $(date)"
    
    # Extract and save deployment information
    echo "Extracting deployment information..."
    terraform output -json > "${RANGE_DIR}/ubuntu-output.json"
    
    # Create a summary file
    cat > "${RANGE_DIR}/ubuntu-summary.txt" <<EOF
Ubuntu Servers Deployment Summary for Range: ${RANGE_ID}
======================================================
Deployment completed at: $(date)
AWS Region: ${AWS_REGION}
Ubuntu Subnet: ${UBUNTU_SUBNET}

Server Information:
$(jq -r '.private_ips.value | to_entries | map("- Ubuntu " + (.key + 1 | tostring) + ": " + .value) | .[]' "${RANGE_DIR}/ubuntu-output.json")

SSH Access:
$(jq -r '.ssh_commands.value | to_entries | map("- Ubuntu " + (.key + 1 | tostring) + ": " + .value) | .[]' "${RANGE_DIR}/ubuntu-output.json")

RDP Access:
$(jq -r '.rdp_commands.value | to_entries | map("- Ubuntu " + (.key + 1 | tostring) + ": " + .value) | .[]' "${RANGE_DIR}/ubuntu-output.json")

Desktop Environment: $([ "$ENABLE_DESKTOP" == "true" ] && echo "Enabled" || echo "Disabled")
RDP Access: $([ "$INSTALL_RDP" == "true" ] && echo "Enabled" || echo "Disabled")

Note: It may take a few minutes after deployment for all services to be ready.
If you can't connect immediately, wait a few minutes and try again.
EOF
    
    echo "Ubuntu servers deployment summary saved to: ${RANGE_DIR}/ubuntu-summary.txt"
    return 0
else
    echo "ERROR: Ubuntu servers deployment failed. Check logs at: $LOGFILE"
    return 1
fi
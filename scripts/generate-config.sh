#!/bin/bash
# generate-config.sh - Generate range-specific configuration

# Check arguments
if [ $# -lt 4 ]; then
    echo "Usage: $0 <range-id> <key-pair> <aws-region> <aws-az>"
    exit 1
fi

RANGE_ID=$1
KEY_PAIR=$2
AWS_REGION=$3
AWS_AZ=$4

# Generate a unique range number (1-254) from the range ID
RANGE_NUM=$(echo $RANGE_ID | md5sum | tr -d -c 0-9 | head -c 3)

RANGE_NUM=$((RANGE_NUM % 254 + 1))

# Generate unique CIDR blocks for the range
GOAD_CIDR="192.168.${RANGE_NUM}.0/24"
UBUNTU_CIDR="10.${RANGE_NUM}.0.0/16"
UBUNTU_SUBNET="10.${RANGE_NUM}.1.0/24"

# Generate Ubuntu instance IP addresses using the GOAD CIDR range
# This will help ensure connectivity between Ubuntu and GOAD
UBUNTU_IP_1="192.168.${RANGE_NUM}.80"
UBUNTU_IP_2="192.168.${RANGE_NUM}.81"
UBUNTU_IP_3="192.168.${RANGE_NUM}.82"

# Generate GOAD instance IP addresses
GOAD_DC1_IP="192.168.${RANGE_NUM}.10"
GOAD_DC2_IP="192.168.${RANGE_NUM}.11"
GOAD_SRV_IP="192.168.${RANGE_NUM}.22"
GOAD_WS01_IP="192.168.${RANGE_NUM}.31"

# Create a JSON configuration
cat <<EOF
{
  "range_id": "${RANGE_ID}",
  "range_number": ${RANGE_NUM},
  "aws_region": "${AWS_REGION}",
  "aws_availability_zone": "${AWS_AZ}",
  "key_name": "${KEY_PAIR}",
  "instance_type": "t2.2xlarge",
  "instance_count": 3,
  "root_volume_size": 50,
  "goad_cidr": "${GOAD_CIDR}",
  "ubuntu_cidr": "${UBUNTU_CIDR}",
  "ubuntu_subnet": "${UBUNTU_SUBNET}",
  "ubuntu_ips": [
    "${UBUNTU_IP_1}",
    "${UBUNTU_IP_2}",
    "${UBUNTU_IP_3}"
  ],
  "goad_ips": {
    "dc1": "${GOAD_DC1_IP}",
    "dc2": "${GOAD_DC2_IP}",
    "srv": "${GOAD_SRV_IP}",
    "ws01": "${GOAD_WS01_IP}"
  },
  "goad_domains": {
    "parent": "sevenkingdoms.local",
    "child": "north.sevenkingdoms.local"
  },
  "hostnames": {
    "dc1": "kingslanding",
    "dc2": "winterfell",
    "srv": "castelblack",
    "ws01": "desktop",
    "ubuntu1": "${RANGE_ID}-ubuntu1",
    "ubuntu2": "${RANGE_ID}-ubuntu2",
    "ubuntu3": "${RANGE_ID}-ubuntu3"
  },
  "enable_desktop": true,
  "install_rdp": true,
  "tags": {
    "Environment": "GOAD-Lab",
    "RangeID": "${RANGE_ID}",
    "Project": "GOAD-Multi-Range"
  },
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
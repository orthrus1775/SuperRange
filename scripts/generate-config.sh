#!/bin/bash

# NEEDS UPDATES  

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Set error handling
set -e
trap 'echo -e "${RED}Error: Command failed at line $LINENO${NC}"; exit 1' ERR

# Check if range ID is provided
if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Range ID is required.${NC}"
    echo -e "Usage: $0 <range_id>"
    exit 1
fi

RANGE_ID="$1"
RANGE_DIR="ranges/range${RANGE_ID}"
CONFIG_FILE="${RANGE_DIR}/range-config.json"

# Get AWS region from environment variable or default to us-east-1
AWS_REGION=${TF_VAR_aws_region:-us-east-1}
AWS_KEY_PAIR=${TF_VAR_aws_key_pair:-"default"}

# Create range directory if it doesn't exist
mkdir -p "$RANGE_DIR"

echo -e "${GREEN}Generating configuration for Range ${RANGE_ID}...${NC}"

# Calculate network configuration based on range ID
VPC_CIDR="10.${RANGE_ID}.0.0/16"
SUBNET_CIDR="10.${RANGE_ID}.1.0/24"
GOAD_NETWORK="192.168.${RANGE_ID}.0/24"

# Generate range-config.json
cat > "$CONFIG_FILE" <<EOF
{
  "range_id": "range${RANGE_ID}",
  "range_number": ${RANGE_ID},
  "aws_region": "${AWS_REGION}",
  "aws_key_pair": "${AWS_KEY_PAIR}",
  "vpc_cidr": "${VPC_CIDR}",
  "subnet_cidr": "${SUBNET_CIDR}",
  "goad_network": "${GOAD_NETWORK}",
  "desktop_environment": {
    "enabled": true,
    "type": "xfce"
  },
  "rdp_access": {
    "enabled": true,
    "port": 3389
  },
  "attackboxes": {
    "count": 3,
    "instance_type": "t2.2xlarge",
    "ubuntu_version": "24.04",
    "username": "ubuntu",
    "password": "Password123!",
    "ip_start": 80,
    "tools": [
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
  },
  "tags": {
    "Project": "SuperRange",
    "Environment": "Training",
    "RangeID": "range${RANGE_ID}"
  },
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

echo -e "${GREEN}Configuration generated for Range ${RANGE_ID} at ${CONFIG_FILE}${NC}"
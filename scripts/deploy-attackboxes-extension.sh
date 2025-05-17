#!/bin/bash

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
GOAD_DIR="${RANGE_DIR}/goad"
EXTENSION_DIR="${GOAD_DIR}/extensions/attackboxes"
CONFIG_FILE="${RANGE_DIR}/range-config.json"

# Check if range directory exists
if [ ! -d "$RANGE_DIR" ]; then
    echo -e "${RED}Error: Range directory does not exist: $RANGE_DIR${NC}"
    exit 1
fi

# Check if GOAD directory exists
if [ ! -d "$GOAD_DIR" ]; then
    echo -e "${RED}Error: GOAD directory does not exist: $GOAD_DIR${NC}"
    exit 1
fi

# Check if attackboxes extension directory exists
if [ ! -d "$EXTENSION_DIR" ]; then
    echo -e "${RED}Error: Attackboxes extension directory does not exist: $EXTENSION_DIR${NC}"
    exit 1
fi

# Check if range configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Range configuration file does not exist: $CONFIG_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}Deploying attackboxes for Range ${RANGE_ID}...${NC}"

# Get network configuration from range config
VPC_CIDR=$(jq -r '.vpc_cidr' "$CONFIG_FILE")
SUBNET_CIDR=$(jq -r '.subnet_cidr' "$CONFIG_FILE")
RANGE_NUMBER=$(jq -r '.range_number' "$CONFIG_FILE")
AWS_REGION=$(jq -r '.aws_region' "$CONFIG_FILE")

# Extract GOAD network details for integrating attackboxes
GOAD_VPC_ID=$(cd "$GOAD_DIR" && terraform output -json | jq -r '.vpc_id.value')
GOAD_SUBNET_ID=$(cd "$GOAD_DIR" && terraform output -json | jq -r '.subnet_id.value')
GOAD_SECURITY_GROUP_ID=$(cd "$GOAD_DIR" && terraform output -json | jq -r '.security_group_id.value')

# Generate terraform.tfvars for attackboxes extension
cat > "${EXTENSION_DIR}/terraform.tfvars" <<EOF
range_number = "${RANGE_NUMBER}"
vpc_cidr = "${VPC_CIDR}"
subnet_cidr = "${SUBNET_CIDR}"
aws_region = "${AWS_REGION}"
goad_vpc_id = "${GOAD_VPC_ID}"
goad_subnet_id = "${GOAD_SUBNET_ID}"
goad_security_group_id = "${GOAD_SECURITY_GROUP_ID}"
EOF

# Change to the GOAD directory and deploy
cd "$GOAD_DIR"
echo -e "${YELLOW}Running GOAD attackboxes extension deployment...${NC}"
./goad.sh -e attackboxes

echo -e "${GREEN}Attackboxes deployed successfully for Range ${RANGE_ID}.${NC}"

# Save deployment outputs to range config
ATTACKBOXES_IPS=$(cd "$EXTENSION_DIR" && terraform output -json attackboxes_ips 2>/dev/null || echo '["N/A"]')
ATTACKBOXES_PUBLIC_IPS=$(cd "$EXTENSION_DIR" && terraform output -json attackboxes_public_ips 2>/dev/null || echo '["N/A"]')

# Update range configuration with attackboxes info
jq --argjson ips "$ATTACKBOXES_IPS" --argjson public_ips "$ATTACKBOXES_PUBLIC_IPS" \
    '.attackboxes = {"ips": $ips, "public_ips": $public_ips}' \
    "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && \
mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

echo -e "${GREEN}Updated range configuration with attackboxes information.${NC}"
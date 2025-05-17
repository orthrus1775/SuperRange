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
CONFIG_FILE="${RANGE_DIR}/range-config.json"
GOAD_DIR="${RANGE_DIR}/goad"

# Check if range directory exists
if [ ! -d "$RANGE_DIR" ]; then
    echo -e "${RED}Error: Range directory does not exist: $RANGE_DIR${NC}"
    exit 1
fi

# Check if GOAD directory exists
if [ ! -d "$GOAD_DIR" ]; then
    echo -e "${YELLOW}GOAD directory does not exist: $GOAD_DIR. Skipping destruction.${NC}"
    exit 0
fi

echo -e "${GREEN}Destroying GOAD for Range ${RANGE_ID}...${NC}"

# Check if terraform.tfstate exists
if [ ! -f "${GOAD_DIR}/terraform.tfstate" ]; then
    echo -e "${YELLOW}No terraform state found in GOAD directory. Skipping destruction.${NC}"
    exit 0
fi

# Get range configuration for AWS settings
if [ -f "$CONFIG_FILE" ]; then
    AWS_REGION=$(jq -r '.aws_region // "us-east-1"' "$CONFIG_FILE")
    AWS_KEY_PAIR=$(jq -r '.aws_key_pair // "default"' "$CONFIG_FILE")
    
    # Set AWS environment variables
    export AWS_REGION="$AWS_REGION"
    export AWS_DEFAULT_REGION="$AWS_REGION"
    export TF_VAR_aws_key_name="$AWS_KEY_PAIR"
else
    echo -e "${YELLOW}Range configuration file not found: $CONFIG_FILE. Using default AWS settings.${NC}"
fi

# Change to GOAD directory
cd "$GOAD_DIR"

# Destroy GOAD
echo -e "${YELLOW}Destroying GOAD deployment (including attackboxes extension)...${NC}"
./goad.sh -t destroy -p aws -m local

# Check if destruction was successful
if [ $? -eq 0 ]; then
    echo -e "${GREEN}GOAD destroyed successfully for Range ${RANGE_ID}.${NC}"
    
    # Update range configuration to remove IPs if the config file exists
    if [ -f "$CONFIG_FILE" ]; then
        cd - > /dev/null  # Go back to previous directory
        jq 'del(.goad) | del(.attackboxes.deployed_ips) | del(.attackboxes.deployed_public_ips)' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && \
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        echo -e "${GREEN}Range configuration updated to remove IPs.${NC}"
    fi
else
    echo -e "${RED}Error: GOAD destruction failed for Range ${RANGE_ID}.${NC}"
    exit 1
    
fi
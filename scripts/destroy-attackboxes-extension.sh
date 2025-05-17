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
    echo -e "${YELLOW}GOAD directory does not exist: $GOAD_DIR. Skipping attackboxes destruction.${NC}"
    exit 0
fi

# Check if attackboxes extension directory exists
if [ ! -d "$EXTENSION_DIR" ]; then
    echo -e "${YELLOW}Attackboxes extension directory does not exist: $EXTENSION_DIR. Skipping.${NC}"
    exit 0
fi

echo -e "${GREEN}Destroying attackboxes for Range ${RANGE_ID}...${NC}"

# Change to the GOAD directory and destroy the extension
cd "$GOAD_DIR"
echo -e "${YELLOW}Running GOAD attackboxes extension destruction...${NC}"

# Check if the extension is deployed before attempting to destroy
if [ -f "${EXTENSION_DIR}/terraform.tfstate" ]; then
    # Use the GOAD script to destroy the extension
    ./goad.sh -d -e attackboxes
else
    echo -e "${YELLOW}No terraform state found for attackboxes extension. Skipping destruction.${NC}"
fi

echo -e "${GREEN}Attackboxes destroyed successfully for Range ${RANGE_ID}.${NC}"

# Update range configuration to remove attackboxes info if the config file exists
if [ -f "$CONFIG_FILE" ]; then
    jq 'del(.attackboxes)' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && \
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo -e "${GREEN}Updated range configuration to remove attackboxes information.${NC}"
fi
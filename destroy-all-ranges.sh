#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Set error handling
set -e
trap 'echo -e "${RED}Error: Command failed at line $LINENO${NC}"; exit 1' ERR

# Configuration
DEPLOYMENT_STATUS_FILE="deployment-status.json"

# Function to update deployment status
update_status() {
    local range_id="$1"
    local status="$2"
    local details="$3"
    
    # Update the JSON file using jq
    jq --arg id "$range_id" --arg status "$status" --arg details "$details" \
       '.ranges[$id] = {"status": $status, "details": $details}' \
       "$DEPLOYMENT_STATUS_FILE" > "${DEPLOYMENT_STATUS_FILE}.tmp" && \
    mv "${DEPLOYMENT_STATUS_FILE}.tmp" "$DEPLOYMENT_STATUS_FILE"
}

# Destroy a single range
destroy_range() {
    local range_id="$1"
    local range_dir="ranges/range${range_id}"
    
    echo -e "${GREEN}Destroying Range ${range_id}...${NC}"
    
    if [ ! -d "$range_dir" ]; then
        echo -e "${YELLOW}Range ${range_id} directory does not exist. Skipping.${NC}"
        return 0
    fi
    
    update_status "$range_id" "destroying" "Starting destruction"
    
    # Destroy GOAD for the range (including attackboxes)
    echo -e "${YELLOW}Destroying GOAD for Range ${range_id}...${NC}"
    if [ -d "$range_dir/goad" ]; then
        ./scripts/destroy-goad.sh "$range_id"
    else
        echo -e "${YELLOW}No GOAD deployment found for Range ${range_id}. Skipping.${NC}"
    fi
    
    # Update status
    
    update_status "$range_id" "destroyed" "Destruction completed successfully"
    echo -e "${GREEN}Range ${range_id} destroyed successfully.${NC}"
}

# Main function to destroy all ranges
destroy_all_ranges() {
    echo -e "${GREEN}Preparing to destroy all ranges...${NC}"
    
    # Get all deployed ranges from status file
    if [ -f "$DEPLOYMENT_STATUS_FILE" ]; then
        RANGES=$(jq -r '.ranges | keys[]' "$DEPLOYMENT_STATUS_FILE")
    else
        echo -e "${YELLOW}No deployment status file found. Scanning ranges directory...${NC}"
        RANGES=$(find ranges -maxdepth 1 -name "range*" | sed 's/.*range//')
    fi
    
    if [ -z "$RANGES" ]; then
        echo -e "${YELLOW}No ranges found to destroy.${NC}"
        exit 0
    fi
    
    echo -e "${YELLOW}The following ranges will be destroyed:${NC}"
    for range_id in $RANGES; do
        echo -e "  - Range $range_id"
    done
    
    # Ask for confirmation
    read -p "Are you sure you want to destroy these ranges? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo -e "${YELLOW}Destruction cancelled.${NC}"
        exit 0
    fi
    
    # Destroy each range
    for range_id in $RANGES; do
        destroy_range "$range_id"
    done
    
    echo -e "${GREEN}All ranges destroyed successfully.${NC}"
    
    # Update dashboard
    if [ -f "./scripts/generate-dashboard.sh" ]; then
        ./scripts/generate-dashboard.sh
        echo -e "${GREEN}Dashboard updated at: ./dashboard/index.html${NC}"
    fi
}

# Run the main function
destroy_all_ranges
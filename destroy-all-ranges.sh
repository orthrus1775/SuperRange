#!/bin/bash
# destroy-all-ranges.sh - Script to destroy all deployed ranges

set -e # Exit on any error

# Configuration
RANGES=("range1" "range2" "range3" "range4" "range5" "range6")
BASE_DIR="./ranges"
SCRIPT_DIR="./scripts"

# Display banner
echo "=================================================="
echo "  GOAD Multi-Range Destruction System"
echo "=================================================="
echo "- This script will DESTROY ${#RANGES[@]} independent ranges"
echo "- ALL resources will be terminated and data will be LOST"
echo "- This action is IRREVERSIBLE"
echo ""

# Check for required tools
echo "Checking prerequisites..."
command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required but not installed. Aborting."; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "Terraform is required but not installed. Aborting."; exit 1; }

# Prompt for confirmation with range ID typing
CONFIRM_STRING="DESTROY-ALL-RANGES"
echo "This operation will destroy all ranges and cannot be undone."
echo "To confirm, type '$CONFIRM_STRING' (case sensitive):"
read INPUT_STRING
if [ "$INPUT_STRING" != "$CONFIRM_STRING" ]; then
    echo "Destruction canceled. Input did not match '$CONFIRM_STRING'"
    exit 1
fi

# Track destruction status
echo "{\"destruction\": {\"start_time\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\", \"ranges\": {}}}" > destruction-status.json

# Destroy ranges in reverse order (in case of dependencies)
for ((i=${#RANGES[@]}-1; i>=0; i--)); do
    RANGE=${RANGES[i]}
    
    echo ""
    echo "=================================================="
    echo "Destroying range: $RANGE"
    echo "=================================================="
    
    # Update status
    jq ".destruction.ranges[\"$RANGE\"] = {\"status\": \"destroying\"}" destruction-status.json > temp.json && mv temp.json destruction-status.json
    
    # 1. Destroy Ubuntu servers first
    echo "Destroying Ubuntu servers..."
    if [ -d "$BASE_DIR/$RANGE/ubuntu-servers" ]; then
        if $SCRIPT_DIR/destroy-ubuntu.sh "$RANGE" "$BASE_DIR"; then
            jq ".destruction.ranges[\"$RANGE\"].ubuntu_status = \"destroyed\"" destruction-status.json > temp.json && mv temp.json destruction-status.json
            echo "Ubuntu servers destroyed for $RANGE"
        else
            jq ".destruction.ranges[\"$RANGE\"].ubuntu_status = \"failed\"" destruction-status.json > temp.json && mv temp.json destruction-status.json
            echo "ERROR: Failed to destroy Ubuntu servers for $RANGE"
        fi
    else
        echo "Ubuntu servers directory not found for $RANGE, skipping..."
    fi
    
    # 2. Destroy GOAD-Light
    echo "Destroying GOAD-Light environment..."
    if [ -d "$BASE_DIR/$RANGE/goad" ]; then
        if $SCRIPT_DIR/destroy-goad.sh "$RANGE" "$BASE_DIR"; then
            jq ".destruction.ranges[\"$RANGE\"].goad_status = \"destroyed\"" destruction-status.json > temp.json && mv temp.json destruction-status.json
            echo "GOAD-Light destroyed for $RANGE"
        else
            jq ".destruction.ranges[\"$RANGE\"].goad_status = \"failed\"" destruction-status.json > temp.json && mv temp.json destruction-status.json
            echo "ERROR: Failed to destroy GOAD-Light for $RANGE"
        fi
    else
        echo "GOAD directory not found for $RANGE, skipping..."
    fi
    
    # 3. Clean up range directory (optional)
    read -p "Do you want to remove all files for $RANGE? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Removing range directory..."
        rm -rf "$BASE_DIR/$RANGE"
        echo "Range directory removed."
    else
        echo "Range directory kept for reference."
    fi
    
    # Update status
    jq ".destruction.ranges[\"$RANGE\"].status = \"completed\"" destruction-status.json > temp.json && mv temp.json destruction-status.json
    
    echo "Range $RANGE destruction complete"
done

# Update final status
jq ".destruction.end_time = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\", .destruction.status = \"completed\"" destruction-status.json > temp.json && mv temp.json destruction-status.json


echo ""
echo "=================================================="
echo "All ranges destroyed successfully!"
echo "=================================================="
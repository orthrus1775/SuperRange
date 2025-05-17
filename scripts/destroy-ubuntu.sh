#!/bin/bash
# destroy-ubuntu.sh - Destroy Ubuntu servers for a specific range

# PENDING REMOVAL


set -e # Exit on any error
exit 1
# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <range-id> <base-dir>"
    exit 1
fi

RANGE_ID=$1
BASE_DIR=$2
RANGE_DIR="${BASE_DIR}/${RANGE_ID}"
UBUNTU_DIR="${RANGE_DIR}/ubuntu-servers"

# Check if Ubuntu servers directory exists
if [ ! -d "$UBUNTU_DIR" ]; then
    echo "Ubuntu servers directory not found: $UBUNTU_DIR"
    exit 1
fi

echo "Destroying Ubuntu servers for range: $RANGE_ID"

# Navigate to Ubuntu servers directory
cd "$UBUNTU_DIR"

# Check if Terraform state exists
if [ ! -f "terraform.tfstate" ]; then
    echo "No Terraform state found in $UBUNTU_DIR"
    exit 1
fi

# Create a log file
LOGFILE="${RANGE_DIR}/ubuntu-destruction.log"
touch "$LOGFILE"

# Run Terraform destroy
echo "Running Terraform destroy..."
terraform destroy -auto-approve | tee -a "$LOGFILE"

# Check if destroy was successful
if [ $? -eq 0 ]; then
    echo "Ubuntu servers destroyed successfully for range: $RANGE_ID"
    
    # Create a record of the destruction
    cat > "${RANGE_DIR}/ubuntu-destroyed.txt" <<EOF
Ubuntu Servers Destruction for Range: ${RANGE_ID}
================================================
Destroyed at: $(date)
EOF
    
    return 0
else
    echo "ERROR: Failed to destroy Ubuntu servers for range: $RANGE_ID"
    echo "Check logs at: $LOGFILE"
    
    return 1
fi
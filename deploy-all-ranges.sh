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
RANGES=(1 2 3) # Default: Deploy 3 ranges
DEPLOYMENT_STATUS_FILE="deployment-status.json"
GOAD_REPO="https://github.com/Orange-Cyberdefense/GOAD.git"
GOAD_BRANCH="main"
ATTACKBOXES_DIR="./attackboxes"

# Ensure necessary directories exist
mkdir -p ranges
mkdir -p dashboard


# Initialize deployment status file if it doesn't exist
if [ ! -f "$DEPLOYMENT_STATUS_FILE" ]; then
    echo '{"ranges": {}}' > "$DEPLOYMENT_STATUS_FILE"
fi

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

# Check prerequisites
check_prerequisites() {
    echo -e "${GREEN}Checking prerequisites...${NC}"
    
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}Error: Terraform is not installed.${NC}"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is not installed.${NC}"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}Error: AWS CLI is not installed.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}All prerequisites are met.${NC}"
}

# Get AWS configuration from user
get_aws_config() {
    echo -e "${GREEN}AWS Configuration${NC}"
    
    # Get AWS key pair
    read -p "Enter AWS key pair name: " AWS_KEY_PAIR
    
    # Get AWS region
    read -p "Enter AWS region (default: us-east-1): " AWS_REGION
    AWS_REGION=${AWS_REGION:-us-east-1}
    read -p "Enter AWS region (default: us-east-1a): " AWS_ZONE
    AWS_ZONE=${AWS_ZONE:-us-east-1a}
    
    # Export as environment variables
    export TF_VAR_aws_key_pair="$AWS_KEY_PAIR"
    export TF_VAR_aws_region="$AWS_REGION"
    export TF_VAR_aws_zone="$AWS_ZONE"
    echo -e "${GREEN}AWS configuration set.${NC}"
}

# Deploy a single range
deploy_range() {
    local range_id="$1"
    local range_dir="ranges/range${range_id}"
    
    echo -e "${GREEN}Deploying Range ${range_id}...${NC}"
    update_status "$range_id" "deploying" "Starting deployment"
    
    # Create range directory if it doesn't exist
    mkdir -p "$range_dir"
    
    # Generate range configuration
    ./scripts/generate-config.sh "$range_id"
    
    # Create GOAD directory if it doesn't exist
    if [ ! -d "$range_dir/goad" ]; then
        echo -e "${YELLOW}Cloning GOAD repository for Range ${range_id}...${NC}"
        git clone --branch "$GOAD_BRANCH" "$GOAD_REPO" "$range_dir/goad"
    else
        echo -e "${YELLOW}GOAD repository already exists for Range ${range_id}. Pulling latest changes...${NC}"
        (cd "$range_dir/goad" && git pull)
    fi

   
    # Copy attackboxes extension to the range's GOAD extensions folder
    echo -e "${YELLOW}Copying attackboxes extension to Range ${range_id}...${NC}"
    cp -r "$ATTACKBOXES_DIR" "$range_dir/goad/extensions/"
    
    # Deploy GOAD with workstation and attackboxes for the range
    echo -e "${YELLOW}Deploying GOAD with attackboxes for Range ${range_id}...${NC}"
    ./scripts/deploy-goad.sh "$range_id"
    
    # Generate documentation for the range
    echo -e "${YELLOW}Generating documentation for Range ${range_id}...${NC}"
    ./scripts/generate-docs.sh "$range_id"
    
    update_status "$range_id" "deployed" "Deployment completed successfully"
    echo -e "${GREEN}Range ${range_id} deployed successfully.${NC}"
}

# Main function to deploy all ranges
deploy_all_ranges() {
    check_prerequisites
    get_aws_config
    
    echo -e "${GREEN}Deploying ${#RANGES[@]} ranges...${NC}"
    
    for range_id in "${RANGES[@]}"; do
        deploy_range "$range_id"
    done
    
    # Generate dashboard
    ./scripts/generate-dashboard.sh
    
    echo -e "${GREEN}All ranges deployed successfully.${NC}"
    echo -e "${GREEN}Dashboard generated at: ./dashboard/index.html${NC}"
}

# Run the main function
deploy_all_ranges
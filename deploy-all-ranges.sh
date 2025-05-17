#!/bin/bash
# deploy-all-ranges.sh - Master script to deploy multiple GOAD ranges

set -e # Exit on any error

# Configuration
RANGES=("range1" "range2")
BASE_DIR="./ranges"
SCRIPT_DIR="./scripts"

# Display banner
echo "=================================================="
echo "  GOAD Multi-Range Deployment System"
echo "=================================================="
echo "- This script will deploy ${#RANGES[@]} independent ranges"
echo "- Each range includes GOAD-Light and 3 Ubuntu servers"
echo "- Estimated deployment time: 1-2 hours per range"
echo ""

# Check for required tools
echo "Checking prerequisites..."
command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required but not installed. Aborting."; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "Terraform is required but not installed. Aborting."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required but not installed. Aborting."; exit 1; }
command -v git >/dev/null 2>&1 || { echo "git is required but not installed. Aborting."; exit 1; }

# Prompt for confirmation
read -p "This will deploy ${#RANGES[@]} ranges. Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment canceled."
    exit 1
fi

# Prompt for AWS key pair to use
read -p "Enter the AWS key pair name to use for all ranges: " KEY_PAIR
if [ -z "$KEY_PAIR" ]; then
    echo "Key pair name is required. Aborting."
    exit 1
fi

# Prompt for AWS region
read -p "Enter AWS region (default: us-east-1): " AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}

# Prompt for AWS availability zone
read -p "Enter AWS availability zone (default: ${AWS_REGION}a): " AWS_AZ
AWS_AZ=${AWS_AZ:-${AWS_REGION}a}

# Ensure base directory exists
mkdir -p $BASE_DIR

# Track deployment status
echo "{\"ranges\": {}}" > deployment-status.json

# For each range
for RANGE in "${RANGES[@]}"; do
  echo ""
  echo "=================================================="
  echo "Setting up range: $RANGE"
  echo "=================================================="
  
  # Update status
  jq ".ranges[\"$RANGE\"] = {\"status\": \"initializing\", \"start_time\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}" deployment-status.json > temp.json && mv temp.json deployment-status.json
  
  # 1. Create range directory structure
  echo "Creating directory structure..."
  mkdir -p "$BASE_DIR/$RANGE/goad"
  mkdir -p "$BASE_DIR/$RANGE/ubuntu-servers"
  mkdir -p "$BASE_DIR/$RANGE/docs"
  
  # 2. Generate range-specific configuration
  echo "Generating range configuration..."
  $SCRIPT_DIR/generate-config.sh "$RANGE" "$KEY_PAIR" "$AWS_REGION" "$AWS_AZ" > "$BASE_DIR/$RANGE/range-config.json"
  
  # 3. Deploy GOAD-Light
  echo "Deploying GOAD-Light environment..."
  if $SCRIPT_DIR/deploy-goad.sh "$RANGE" "$BASE_DIR"; then
    # Update status
    jq ".ranges[\"$RANGE\"].goad_status = \"deployed\"" deployment-status.json > temp.json && mv temp.json deployment-status.json
    echo "GOAD-Light deployment completed for $RANGE"
  else
    # Update status
    jq ".ranges[\"$RANGE\"].goad_status = \"failed\"" deployment-status.json > temp.json && mv temp.json deployment-status.json
    echo "ERROR: GOAD-Light deployment failed for $RANGE"
    continue
  fi
  
  # 4. Deploy Ubuntu servers
  echo "Deploying Ubuntu servers..."
  if $SCRIPT_DIR/deploy-ubuntu.sh "$RANGE" "$BASE_DIR"; then
    # Update status
    jq ".ranges[\"$RANGE\"].ubuntu_status = \"deployed\"" deployment-status.json > temp.json && mv temp.json deployment-status.json
    echo "Ubuntu servers deployment completed for $RANGE"
  else
    # Update status
    jq ".ranges[\"$RANGE\"].ubuntu_status = \"failed\"" deployment-status.json > temp.json && mv temp.json deployment-status.json
    echo "ERROR: Ubuntu servers deployment failed for $RANGE"
  fi
  
  # 5. Generate documentation
  echo "Generating documentation..."
  $SCRIPT_DIR/generate-docs.sh "$RANGE" "$BASE_DIR"
  
  # Update status
  jq ".ranges[\"$RANGE\"].status = \"completed\", .ranges[\"$RANGE\"].end_time = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"" deployment-status.json > temp.json && mv temp.json deployment-status.json
  
  echo "Range $RANGE deployment complete"
done

# Generate consolidated dashboard
echo ""
echo "Generating dashboard..."
$SCRIPT_DIR/generate-dashboard.sh "${RANGES[@]}" "$BASE_DIR"


echo ""
echo "=================================================="
echo "All ranges deployed successfully!"
echo "See dashboard.html for access information"
echo "=================================================="
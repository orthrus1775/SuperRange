#!/bin/bash
# deploy-goad.sh - Deploy GOAD-Light for a specific range

set -e # Exit on any error

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <range-id> <base-dir>"
    exit 1
fi

RANGE_ID=$1
BASE_DIR=$2
RANGE_DIR="${BASE_DIR}/${RANGE_ID}"
GOAD_DIR="${RANGE_DIR}/goad"
CONFIG_FILE="${RANGE_DIR}/range-config.json"

# Check if configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Load configuration
RANGE_NUM=$(jq -r '.range_number' "$CONFIG_FILE")
AWS_REGION=$(jq -r '.aws_region' "$CONFIG_FILE")
GOAD_CIDR=$(jq -r '.goad_cidr' "$CONFIG_FILE")
KEY_NAME=$(jq -r '.key_name' "$CONFIG_FILE")

echo "Deploying GOAD-Light for range: $RANGE_ID (Range #$RANGE_NUM)"
echo "- AWS Region: $AWS_REGION"
echo "- GOAD CIDR: $GOAD_CIDR"
echo "- Key Name: $KEY_NAME"

# Clone GOAD repository if not already cloned
if [ ! -d "${GOAD_DIR}/.git" ]; then
    echo "Cloning GOAD repository..."
    git clone https://github.com/Orange-Cyberdefense/GOAD.git "$GOAD_DIR"
fi

# Navigate to GOAD directory
cd "$GOAD_DIR"

# Update Windows AMI IDs to the latest version
echo "Finding latest Windows Server 2019 AMI for region $AWS_REGION..."

# Use AWS CLI to find the latest Windows Server 2019 AMI in the specified region
LATEST_WIN_AMI=$(aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=Windows_Server-2019-English-Full-Base-*" "Name=state,Values=available" \
    --query "sort_by(Images, &CreationDate)[-1].ImageId" \
    --output text \
    --region "$AWS_REGION")

if [ -z "$LATEST_WIN_AMI" ]; then
    echo "ERROR: Failed to retrieve latest Windows Server 2019 AMI. Check AWS CLI configuration."
    exit 1
fi

echo "Latest Windows Server 2019 AMI for region $AWS_REGION: $LATEST_WIN_AMI"

# Find and update all windows.tf files
find . -name "windows.tf" -exec grep -l "ami-" {} \; | while read -r file; do
    echo "Updating AMI IDs in $file..."
    # Replace any AMI ID that looks like ami-xxxxxxxxxxxxxxxxx with the latest one
    sed -i "s/ami-[a-z0-9]\{17\}/$LATEST_WIN_AMI/g" "$file"
done

# Update GOAD-Light inventory to disable updates and Windows Defender
INVENTORY_FILE="$GOAD_DIR/ad/GOAD-Light/data/inventory"
if [ -f "$INVENTORY_FILE" ]; then
    echo "Updating GOAD inventory to speed up deployment..."
    # Create backup of the original inventory
    cp "$INVENTORY_FILE" "${INVENTORY_FILE}.bak"
    
    # Clear hosts from [update] section and add them to [no_update]
    sed -i '/\[update\]/,/\[no_update\]/ {
        # Delete non-comment lines between sections
        /^\[update\]/b
        /^\[no_update\]/b
        /^;/b
        /^$/b
        d
    }' "$INVENTORY_FILE"
    
    # Add all hosts to [no_update] section
    sed -i '/\[no_update\]/a dc01\ndc02\nsrv02\nws01' "$INVENTORY_FILE"
    
    # Clear hosts from [defender_on] section
    sed -i '/\[defender_on\]/,/\[defender_off\]/ {
        # Delete non-comment lines between sections
        /^\[defender_on\]/b
        /^\[defender_off\]/b
        /^;/b
        /^$/b
        d
    }' "$INVENTORY_FILE"
    
    # Add all hosts to [defender_off] section
    sed -i '/\[defender_off\]/a dc01\ndc02\nsrv02\nws01' "$INVENTORY_FILE"
    
    echo "Inventory updated to disable all updates and Windows Defender."
else
    echo "Warning: GOAD inventory file not found at $INVENTORY_FILE"
fi

# Create GOAD configuration for AWS
echo "Creating GOAD configuration for AWS..."

# Create .goad directory if it doesn't exist
mkdir -p ~/.goad

# Create GOAD configuration file with range-specific settings
cat > ~/.goad/goad.ini <<EOF
[default]
lab = GOAD-Light
provider = aws
provisioner = local
ip_range = 192.168.${RANGE_NUM}

[aws]
aws_region = ${AWS_REGION}
aws_zone = ${AWS_REGION}a
EOF

# Create custom settings for GOAD-Light
mkdir -p "$GOAD_DIR/custom_settings"
cat > "$GOAD_DIR/custom_settings/goad-light-${RANGE_ID}.ini" <<EOF
[defaults]
ansible_user = vagrant
ansible_password = vagrant
ansible_connection = winrm
ansible_winrm_server_cert_validation = ignore
ansible_winrm_operation_timeout_sec = 60
ansible_winrm_read_timeout_sec = 70

[all:vars]
domain_name = sevenkingdoms.local
domain_admin = Administrator
domain_password = Password123!
parent_domain = sevenkingdoms.local
child_domain = north.sevenkingdoms.local
domain_mode = forest
install_tools = yes

[ip]
first_ip = 192.168.${RANGE_NUM}
EOF

# Ensure AWS CLI is configured
if ! aws configure list &>/dev/null; then
    echo "ERROR: AWS CLI is not configured. Please run 'aws configure' first."
    exit 1
fi

# Check AWS permissions
echo "Checking AWS permissions..."
if ! aws ec2 describe-regions --region "$AWS_REGION" &>/dev/null; then
    echo "ERROR: Unable to access AWS. Check your credentials and permissions."
    exit 1
fi

# Deploy GOAD-Light to AWS
echo "Deploying GOAD-Light to AWS (this may take 30+ minutes)..."
echo "Starting deployment at: $(date)"

# Create a log file
LOGFILE="${RANGE_DIR}/goad-deployment.log"
touch "$LOGFILE"

# Run GOAD deployment
echo "Running GOAD deployment (logging to $LOGFILE)..."
(
    set -x # Echo commands for logging
    # Install Python venv if needed
    if ! command -v python3 -m venv &>/dev/null; then
        apt-get update
        apt-get install -y python3-venv
    fi
    
    # Run GOAD deployment command
    ./goad.sh -t install -l GOAD-Light -p aws -m local -e ws01
) 2>&1 | tee -a "$LOGFILE"

# Check if deployment was successful
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "GOAD-Light deployment completed successfully at: $(date)"
    
    # Extract and save GOAD information
    echo "Extracting GOAD deployment information..."
    
    # Save IP addresses
    aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --filters "Name=tag:Environment,Values=GOAD-Light" \
        --query 'Reservations[*].Instances[*].[InstanceId,PrivateIpAddress,PublicIpAddress,Tags[?Key==`Name`].Value]' \
        --output json > "${RANGE_DIR}/goad-instances.json"
    
    echo "GOAD-Light deployment information saved to: ${RANGE_DIR}/goad-instances.json"
    
    # Create a summary file
    cat > "${RANGE_DIR}/goad-summary.txt" <<EOF
GOAD-Light Deployment Summary for Range: ${RANGE_ID}
===================================================
Deployment completed at: $(date)
AWS Region: ${AWS_REGION}
GOAD CIDR: ${GOAD_CIDR}

Domain Information:
- Parent Domain: sevenkingdoms.local
- Child Domain: north.sevenkingdoms.local
- Domain Admin: Administrator
- Password: Password123!

Server Information:
- DC1 (kingslanding): 192.168.${RANGE_NUM}.10
- DC2 (winterfell): 192.168.${RANGE_NUM}.11
- SRV (castelblack): 192.168.${RANGE_NUM}.22
- WS01 (desktop): 192.168.${RANGE_NUM}.31

To connect using RDP:
- Use an RDP client to connect to the public IP addresses
- Username: Administrator
- Password: Password123!
EOF
    
    # Extract and append public IPs to summary
    echo "" >> "${RANGE_DIR}/goad-summary.txt"
    echo "Public IP Addresses:" >> "${RANGE_DIR}/goad-summary.txt"
    jq -r '.[][] | select(.[3][0] != null) | "\(.[3][0]): \(.[2])"' "${RANGE_DIR}/goad-instances.json" >> "${RANGE_DIR}/goad-summary.txt"
    
    echo "GOAD-Light deployment summary saved to: ${RANGE_DIR}/goad-summary.txt"
    return 0
else
    echo "ERROR: GOAD-Light deployment failed. Check logs at: $LOGFILE"
    
    return 1
fi
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

# Check if range configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Range configuration file does not exist: $CONFIG_FILE${NC}"
    exit 1
fi

# Check if GOAD directory exists
if [ ! -d "$GOAD_DIR" ]; then
    echo -e "${RED}Error: GOAD directory does not exist: $GOAD_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}Deploying GOAD for Range ${RANGE_ID}...${NC}"

# Get range configuration
RANGE_NUMBER=$(jq -r '.range_number' "$CONFIG_FILE")
AWS_REGION=$(jq -r '.aws_region' "$CONFIG_FILE")
AWS_ZONE=$(jq -r '.aws_zone' "$CONFIG_FILE")
AWS_KEY_PAIR=$(jq -r '.aws_key_pair' "$CONFIG_FILE")

# Get attackbox configuration
# ATTACKBOX_COUNT=$(jq -r '.attackboxes.count // 3' "$CONFIG_FILE")
# ATTACKBOX_INSTANCE_TYPE=$(jq -r '.attackboxes.instance_type // "t2.2xlarge"' "$CONFIG_FILE")
# ATTACKBOX_IP_START=$(jq -r '.attackboxes.ip_start // 80' "$CONFIG_FILE")

# Change to GOAD directory
cd "$GOAD_DIR"

# Set AWS environment variables
export AWS_REGION="$AWS_REGION"
export AWS_DEFAULT_REGION="$AWS_REGION"
export TF_VAR_aws_key_name="$AWS_KEY_PAIR"
export TF_VAR_range_number="$RANGE_NUMBER"

# Set attackbox environment variables
export TF_VAR_attackbox_count="$ATTACKBOX_COUNT"
export TF_VAR_attackbox_instance_type="$ATTACKBOX_INSTANCE_TYPE"
export TF_VAR_attackbox_ip_start="$ATTACKBOX_IP_START"

# Get the latest Windows Server 2019 AMI for the specified region
echo -e "${YELLOW}Getting latest Windows Server 2019 AMI for region ${AWS_REGION}...${NC}"
WIN_AMI=$(aws ec2 describe-images \
    --region "$AWS_REGION" \
    --owners amazon \
    --filters "Name=name,Values=Windows_Server-2019-English-Full-Base-*" \
    --query "sort_by(Images, &CreationDate)[-1].ImageId" \
    --output text)

if [ -z "$WIN_AMI" ]; then
    echo -e "${RED}Error: Could not find Windows Server 2019 AMI for region ${AWS_REGION}.${NC}"
    exit 1
fi

echo -e "${GREEN}Found Windows Server 2019 AMI: ${WIN_AMI}${NC}"

WINDOWS_TF_PATH=$(pwd)/ad/GOAD-Light/providers/aws/windows.tf
WS_TF_PATH=$(pwd)/extensions/ws01/providers/aws/windows.tf

if [ ! -f "$WINDOWS_TF_PATH" ]; then
    echo -e "${RED}Error: Windows terraform file not found at: $WINDOWS_TF_PATH${NC}"
    exit 1
fi

if [ ! -f "$WS_TF_PATH" ]; then
    echo -e "${RED}Error: Windows terraform file not found at: $WS_TF_PATH${NC}"
    exit 1
fi

echo -e "${YELLOW}Updating Windows AMI IDs in windows.tf...${NC}"
sed -i "s|ami-[a-z0-9]*|${WIN_AMI}|g"  $WINDOWS_TF_PATH
sed -i "s|ami-[a-z0-9]*|${WIN_AMI}|g"  $WS_TF_PATH

echo -e "${GREEN}Updated AMI IDs in windows.tf${NC}"

# Need to update after the clone becasue AMIs differ by region
echo -e "${YELLOW}Getting latest Ubuntu 24.04 LTS AMI for region ${AWS_REGION}...${NC}"
UBUNTU_AMI=$(aws ec2 describe-images \
    --region "$AWS_REGION" \
    --owners 099720109477 \
    --filters "Name=name,Values=*ubuntu*24.04*server*" \
             "Name=architecture,Values=x86_64" \
             "Name=root-device-type,Values=ebs" \
    --query "sort_by(Images, &CreationDate)[-1].ImageId" \
    --output text)

if [ -z "$UBUNTU_AMI" ]; then
    echo -e "${RED}Error: Could not find Ubuntu 24.04 LTS AMI for region ${AWS_REGION}.${NC}"
    exit 1
fi
echo -e "${GREEN}Found Ubuntu 24.04 LTS AMI: ${UBUNTU_AMI}${NC}"

NOBEL_LINUX_TF_PATH=$(pwd)/extensions/attackboxes/providers/aws/linux.tf

if [ ! -f "$NOBEL_LINUX_TF_PATH" ]; then
    echo -e "${RED}Error: Windows terraform file not found at: $NOBEL_LINUX_TF_PATH${NC}"
    exit 1
fi

echo -e "${YELLOW}Updating Windows AMI IDs in attackbox.tf...${NC}"
sed -i "s|ami-[a-z0-9]*|${UBUNTU_AMI}|g"  $NOBEL_LINUX_TF_PATH


UBUNTU_AMI=$(aws ec2 describe-images \
    --region "$AWS_REGION" \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
             "Name=state,Values=available" \
    --query "sort_by(Images, &CreationDate)[-1].ImageId" \
    --output text)

if [ -z "$UBUNTU_AMI" ]; then
    echo -e "${RED}Error: Could not find Ubuntu 22.04 LTS AMI for region ${AWS_REGION}.${NC}"
    exit 1
fi
echo -e "${GREEN}Found Ubuntu 22.04 LTS AMI: ${UBUNTU_AMI}${NC}"

JAMMY_LINUX_TF_PATH=$(pwd)/template/provider/aws/jumpbox.tf

if [ ! -f "$JAMMY_LINUX_TF_PATH" ]; then
    echo -e "${RED}Error: Windows terraform file not found at: $JAMMY_LINUX_TF_PATH${NC}"
    exit 1
fi

echo -e "${YELLOW}Updating Windows AMI IDs in windows.tf...${NC}"
sed -i "s|ami-[a-z0-9]*|${UBUNTU_AMI}|g"  $JAMMY_LINUX_TF_PATH

echo -e "${GREEN}Updated AMI IDs in linux.tf${NC}"

echo -e "${YELLOW}Fixing GOAD Templates...${NC}"  
TEMPLATE_DIR=$(pwd)/template/provider/aws
TAG=Range-${RANGE_ID}
find ${TEMPLATE_DIR} -type f -exec grep -l "{{lab_name}}" {} \; | while read file; do
    sed -i "s/{{lab_name}}/${TAG}/g" "$file"
done

VARS_TF_PATH=${TEMPLATE_DIR}/variables.tf
if [ ! -f "$VARS_TF_PATH" ]; then
    echo -e "${RED}Error: variables terraform file not found at: $VARS_TF_PATH${NC}"
    exit 1
fi
sed -i "s/eu-west-3c/${AWS_ZONE}/g" $VARS_TF_PATH
sed -i "s/eu-west-3/${AWS_REGION}/g" $VARS_TF_PATH

# LIN_TEMPLATE=${TEMPLATE_DIR}/linux.tf
# if [ ! -f "$LIN_TEMPLATE" ]; then
#     echo -e "${RED}Error: Linux terraform file not found at: $LIN_TEMPLATE${NC}"
#     exit 1
# fi
# sed -i 's/aws_subnet\.goad_private_network\.id/aws_subnet.goad_public_network.id/g' $LIN_TEMPLATE

if [ ! -f "globalsettings.ini" ]; then
    echo -e "${RED}Error: Could not find glovalsettings.ini${NC}"
    exit 1
fi
sed -i 's/keyboard_layouts=\["0000040C", "00000409"\]/keyboard_layouts=\["00000409"\]/g' globalsettings.ini
# echo "rangeid=range$RANGE_ID" >> globalsettings.ini

# read -p "Validate setting"

# Deploy GOAD Light with a Windows 10 workstation and attackboxes extension
echo -e "${YELLOW}Deploying GOAD Light with Windows 10 workstation and attackboxes...${NC}"
# ./goad.sh -t install -l GOAD-Light -p aws -m local -e ws01 -e attackboxes
./goad.sh -t install -l GOAD-Light -p aws -m local -e ws01

# Wait for deployment to complete
echo -e "${GREEN}GOAD deployment started. Waiting for completion...${NC}"

# Check if deployment was successful
if [ $? -eq 0 ]; then
    echo -e "${GREEN}GOAD deployed successfully for Range ${RANGE_ID}.${NC}"
    
    # Extract and save IPs to range configuration
    # echo -e "${YELLOW}Extracting IPs and updating range configuration...${NC}"
    
    # # Get IPs from terraform output
    # KINGSLANDING_IP=$(terraform output -json kingslanding_ip | tr -d '"')
    # WINTERFELL_IP=$(terraform output -json winterfell_ip | tr -d '"')
    # CASTELBLACK_IP=$(terraform output -json castelblack_ip | tr -d '"')
    # DESKTOP_IP=$(terraform output -json desktop_ip | tr -d '"')
    
    # KINGSLANDING_PUBLIC_IP=$(terraform output -json kingslanding_public_ip | tr -d '"')
    # WINTERFELL_PUBLIC_IP=$(terraform output -json winterfell_public_ip | tr -d '"')
    # CASTELBLACK_PUBLIC_IP=$(terraform output -json castelblack_public_ip | tr -d '"')
    # DESKTOP_PUBLIC_IP=$(terraform output -json desktop_public_ip | tr -d '"')
    
    # # Get attackboxes IPs
    # ATTACKBOXES_IPS=$(terraform output -json attackboxes_ips 2>/dev/null || echo '["N/A"]')
    # ATTACKBOXES_PUBLIC_IPS=$(terraform output -json attackboxes_public_ips 2>/dev/null || echo '["N/A"]')
    
    # # Update range configuration with IPs
    # cd - > /dev/null  # Go back to previous directory
    
    # # Update with GOAD IPs
    # jq --arg k_ip "$KINGSLANDING_IP" \
    #    --arg w_ip "$WINTERFELL_IP" \
    #    --arg c_ip "$CASTELBLACK_IP" \
    #    --arg d_ip "$DESKTOP_IP" \
    #    --arg k_pub "$KINGSLANDING_PUBLIC_IP" \
    #    --arg w_pub "$WINTERFELL_PUBLIC_IP" \
    #    --arg c_pub "$CASTELBLACK_PUBLIC_IP" \
    #    --arg d_pub "$DESKTOP_PUBLIC_IP" \
    #    --argjson a_ips "$ATTACKBOXES_IPS" \
    #    --argjson a_pubs "$ATTACKBOXES_PUBLIC_IPS" \
    #    '.goad = {
    #       "kingslanding_ip": $k_ip,
    #       "winterfell_ip": $w_ip,
    #       "castelblack_ip": $c_ip,
    #       "desktop_ip": $d_ip,
    #       "kingslanding_public_ip": $k_pub,
    #       "winterfell_public_ip": $w_pub,
    #       "castelblack_public_ip": $c_pub,
    #       "desktop_public_ip": $d_pub
    #     } | .attackboxes.deployed_ips = $a_ips | .attackboxes.deployed_public_ips = $a_pubs' \
    #    "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && \
    # mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    
    # echo -e "${GREEN}Range configuration updated with IPs.${NC}"
else
    echo -e "${RED}Error: GOAD deployment failed for Range ${RANGE_ID}.${NC}"
    exit 1
fi
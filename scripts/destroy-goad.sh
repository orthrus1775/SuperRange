#!/bin/bash
# destroy-goad.sh - Destroy GOAD-Light for a specific range

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

# Check if GOAD directory exists
if [ ! -d "$GOAD_DIR" ]; then
    echo "GOAD directory not found: $GOAD_DIR"
    exit 1
fi

echo "Destroying GOAD-Light for range: $RANGE_ID"

# Navigate to GOAD directory
cd "$GOAD_DIR"

# Create a log file
LOGFILE="${RANGE_DIR}/goad-destruction.log"
touch "$LOGFILE"

# Check if GOAD instances information exists
if [ -f "${RANGE_DIR}/goad-instances.json" ]; then
    echo "Found GOAD instances information..."
    
    # Extract GOAD instance IDs
    INSTANCE_IDS=$(jq -r '.[][][0]' "${RANGE_DIR}/goad-instances.json" | tr '\n' ' ')
    
    if [ -n "$INSTANCE_IDS" ]; then
        echo "Found instance IDs: $INSTANCE_IDS"
        
        # Prompt for confirmation
        read -p "Terminate these instances? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Get configuration
            CONFIG_FILE="${RANGE_DIR}/range-config.json"
            if [ -f "$CONFIG_FILE" ]; then
                AWS_REGION=$(jq -r '.aws_region' "$CONFIG_FILE")
            else
                # Default region if config not found
                AWS_REGION="us-east-1"
            fi
            
            # Terminate instances
            echo "Terminating instances in region $AWS_REGION..."
            for INSTANCE_ID in $INSTANCE_IDS; do
                echo "Terminating instance: $INSTANCE_ID"
                aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" | tee -a "$LOGFILE"
            done
            
            # Wait for instances to terminate
            echo "Waiting for instances to terminate..."
            for INSTANCE_ID in $INSTANCE_IDS; do
                aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"
                echo "Instance $INSTANCE_ID terminated."
            done
        else
            echo "Instance termination aborted."
            return 1
        fi
    else
        echo "No instance IDs found in ${RANGE_DIR}/goad-instances.json"
    fi
fi

# Run GOAD destroy command if available
if [ -f "./goad.sh" ]; then
    echo "Running GOAD destroy command..."
    
    # Ensure .goad directory exists
    mkdir -p ~/.goad
    
    # Get configuration
    CONFIG_FILE="${RANGE_DIR}/range-config.json"
    if [ -f "$CONFIG_FILE" ]; then
        RANGE_NUM=$(jq -r '.range_number' "$CONFIG_FILE")
        AWS_REGION=$(jq -r '.aws_region' "$CONFIG_FILE")
        
        # Create GOAD configuration
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
    fi
    
    # Run GOAD destroy
    ./goad.sh -t destroy -l GOAD-Light -p aws | tee -a "$LOGFILE"
fi

# Create a record of the destruction
cat > "${RANGE_DIR}/goad-destroyed.txt" <<EOF
GOAD-Light Destruction for Range: ${RANGE_ID}
=============================================
Destroyed at: $(date)
EOF

# Cleanup additional AWS resources that might be left behind
if [ -f "$CONFIG_FILE" ]; then
    AWS_REGION=$(jq -r '.aws_region' "$CONFIG_FILE")
    
    echo "Checking for leftover AWS resources in region $AWS_REGION..."
    
    # Look for resources with the RangeID tag
    echo "Looking for EC2 resources with tag RangeID=$RANGE_ID..."
    
    # Find and terminate any remaining instances
    INSTANCES=$(aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --filters "Name=tag:RangeID,Values=$RANGE_ID" "Name=instance-state-name,Values=running,pending,stopping,stopped" \
        --query 'Reservations[*].Instances[*].InstanceId' \
        --output text)
    
    if [ -n "$INSTANCES" ]; then
        echo "Found leftover instances: $INSTANCES"
        aws ec2 terminate-instances --instance-ids $INSTANCES --region "$AWS_REGION" | tee -a "$LOGFILE"
        echo "Waiting for instances to terminate..."
        aws ec2 wait instance-terminated --instance-ids $INSTANCES --region "$AWS_REGION"
    fi
    
    # Find and delete any security groups
    SECURITY_GROUPS=$(aws ec2 describe-security-groups \
        --region "$AWS_REGION" \
        --filters "Name=tag:RangeID,Values=$RANGE_ID" \
        --query 'SecurityGroups[*].GroupId' \
        --output text)
    
    if [ -n "$SECURITY_GROUPS" ]; then
        echo "Found leftover security groups: $SECURITY_GROUPS"
        for SG in $SECURITY_GROUPS; do
            echo "Deleting security group: $SG"
            aws ec2 delete-security-group --group-id "$SG" --region "$AWS_REGION" | tee -a "$LOGFILE"
        done
    fi
    
    # Find and delete any VPCs
    VPCS=$(aws ec2 describe-vpcs \
        --region "$AWS_REGION" \
        --filters "Name=tag:RangeID,Values=$RANGE_ID" \
        --query 'Vpcs[*].VpcId' \
        --output text)
    
    if [ -n "$VPCS" ]; then
        echo "Found leftover VPCs: $VPCS"
        for VPC in $VPCS; do
            # Delete associated subnets
            SUBNETS=$(aws ec2 describe-subnets \
                --region "$AWS_REGION" \
                --filters "Name=vpc-id,Values=$VPC" \
                --query 'Subnets[*].SubnetId' \
                --output text)
            
            if [ -n "$SUBNETS" ]; then
                echo "Deleting subnets for VPC $VPC: $SUBNETS"
                for SUBNET in $SUBNETS; do
                    aws ec2 delete-subnet --subnet-id "$SUBNET" --region "$AWS_REGION" | tee -a "$LOGFILE"
                done
            fi
            
            # Delete associated internet gateways
            IGWs=$(aws ec2 describe-internet-gateways \
                --region "$AWS_REGION" \
                --filters "Name=attachment.vpc-id,Values=$VPC" \
                --query 'InternetGateways[*].InternetGatewayId' \
                --output text)
            
            if [ -n "$IGWs" ]; then
                echo "Detaching and deleting internet gateways for VPC $VPC: $IGWs"
                for IGW in $IGWs; do
                    aws ec2 detach-internet-gateway --internet-gateway-id "$IGW" --vpc-id "$VPC" --region "$AWS_REGION" | tee -a "$LOGFILE"
                    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW" --region "$AWS_REGION" | tee -a "$LOGFILE"
                done
            fi
            
            # Delete the VPC
            echo "Deleting VPC: $VPC"
            aws ec2 delete-vpc --vpc-id "$VPC" --region "$AWS_REGION" | tee -a "$LOGFILE"
        done
    fi
fi

echo "GOAD-Light environment destroyed successfully for range: $RANGE_ID"

return 0
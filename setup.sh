#!/bin/bash
# Make all scripts executable and fix line endings

echo "Setting up GOAD Multi-Range deployment system..."

# Create scripts directory if it doesn't exist
mkdir -p scripts

# Fix line endings for all shell scripts (handles Windows CRLF issues)
echo "Fixing line endings for all scripts..."
find . -type f -name "*.sh" -exec sed -i 's/\r$//' {} \;

# Make main scripts executable
echo "Setting execute permissions for main scripts..."
chmod +x deploy-all-ranges.sh
chmod +x destroy-all-ranges.sh
chmod +x setup.sh

# Make helper scripts executable
echo "Setting execute permissions for helper scripts..."
chmod +x scripts/deploy-goad.sh
chmod +x scripts/deploy-ubuntu.sh
chmod +x scripts/destroy-goad.sh
chmod +x scripts/destroy-ubuntu.sh
chmod +x scripts/generate-config.sh
chmod +x scripts/generate-docs.sh
chmod +x scripts/generate-dashboard.sh

# Create necessary directories
echo "Creating directory structure..."
mkdir -p ranges
mkdir -p dashboard

# Check for required dependencies
echo "Checking for required dependencies..."

# Check for AWS CLI
if ! command -v aws &> /dev/null; then
    echo "WARNING: AWS CLI not found. You'll need to install it before deploying."
    echo "Visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    echo "AWS CLI is required for dynamically finding the latest Windows Server AMI."
else
    # Check AWS CLI configuration
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "WARNING: AWS CLI is installed but not properly configured."
        echo "Run 'aws configure' to set up your AWS credentials."
    else
        echo "AWS CLI is properly configured."
    fi
fi

# Check for Terraform
if ! command -v terraform &> /dev/null; then
    echo "WARNING: Terraform not found. You'll need to install it before deploying."
    echo "Visit: https://developer.hashicorp.com/terraform/install"
fi

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "WARNING: jq not found. You'll need to install it before deploying."
    echo "Install with: apt-get install jq (Ubuntu/Debian) or brew install jq (macOS)"
fi

# Check for git
if ! command -v git &> /dev/null; then
    echo "WARNING: git not found. You'll need to install it before deploying."
    echo "Install with: apt-get install git (Ubuntu/Debian) or brew install git (macOS)"
fi

echo ""
echo "Setup complete! All scripts are now executable and line endings are fixed."
echo ""
echo "To deploy ranges, run:"
echo "  ./deploy-all-ranges.sh"
echo ""
echo "To destroy ranges, run:"
echo "  ./destroy-all-ranges.sh"
echo ""
echo "Visit the README.md for more information."
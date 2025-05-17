#!/bin/bash
# setup.sh - Make all scripts executable, fix line endings, and install dependencies

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

# Check and install required dependencies
echo "Checking and installing required dependencies..."

# Update package list
sudo apt update

# Function to check if package is installed
is_installed() {
    dpkg -l | grep -q "$1"
    return $?
}

# Install multiple packages at once
echo "Installing basic dependencies..."
PACKAGES_TO_INSTALL=""
for pkg in curl unzip git wget jq asciinema libfontconfig1-dev pandoc npm; do
    if ! is_installed $pkg; then
        PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $pkg"
    fi
done

if [ ! -z "$PACKAGES_TO_INSTALL" ]; then
    echo "Installing packages: $PACKAGES_TO_INSTALL"
    sudo apt install -y $PACKAGES_TO_INSTALL
else
    echo "All basic dependencies are already installed."
fi

# Check and install AWS CLI
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
    
    # Create default AWS credentials file if it doesn't exist
    if [ ! -f ~/.aws/credentials ]; then
        echo "Creating default AWS credentials file..."
        mkdir -p ~/.aws
        echo -e "[default]\naws_access_key_id = changeme\naws_secret_access_key = changeme" > ~/.aws/credentials
        echo "Please update ~/.aws/credentials with your actual AWS credentials."
    fi
else
    echo "AWS CLI is already installed."
    # Check AWS CLI configuration
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "WARNING: AWS CLI is installed but not properly configured."
        echo "Run 'aws configure' to set up your AWS credentials."
    else
        echo "AWS CLI is properly configured."
    fi
fi

# Check and install Terraform
if ! command -v terraform &> /dev/null; then
    echo "Installing Terraform..."
    wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install -y terraform
else
    echo "Terraform is already installed."
fi

# Check and install AWS CDK
if ! command -v cdk &> /dev/null; then
    echo "Installing AWS CDK and dependencies..."
    sudo npm install -g aws-cdk
    sudo npm install aws-cdk-lib constructs fs path csv-parser
else
    echo "AWS CDK is already installed."
fi

# Check and install Rust (for agg)
if ! command -v cargo &> /dev/null; then
    echo "Installing Rust..."
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source "$HOME/.cargo/env"
else
    echo "Rust is already installed."
fi

# Install agg (asciinema player)
if ! command -v agg &> /dev/null; then
    echo "Installing agg (asciinema player)..."
    # Make sure we can access cargo even if it was just installed
    source "$HOME/.cargo/env"
    cargo install --git https://github.com/asciinema/agg
else
    echo "agg is already installed."
fi

echo ""
echo "Setup complete! All dependencies are installed, scripts are executable, and line endings are fixed."
echo ""
echo "To deploy ranges, run:"
echo "  ./deploy-all-ranges.sh"
echo ""
echo "To destroy ranges, run:"
echo "  ./destroy-all-ranges.sh"
echo ""
echo "Visit the README.md for more information."
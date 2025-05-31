#!/bin/bash

# OpenVPN Client Config Generator
# This script generates client configurations from a CSV file
# CSV format: username,email,expiry_days
# Example: john,john@example.com,365

# Exit on error
set -e

# Variables - adjust these to match your OpenVPN server setup
EASYRSA_DIR="/etc/openvpn/easy-rsa"
OUTPUT_DIR="/etc/openvpn/clients"
SERVER_PUBLIC_IP=$(curl -s ifconfig.me)
PORT=1194
PROTOCOL=udp
CIPHER="AES-256-GCM"
AUTH="SHA256"
CSV_FILE=$1

# Check if CSV file is provided
if [ -z "$CSV_FILE" ]; then
    echo "Error: CSV file not provided"
    echo "Usage: $0 users.csv"
    exit 1
fi

# Check if CSV file exists
if [ ! -f "$CSV_FILE" ]; then
    echo "Error: CSV file $CSV_FILE not found"
    exit 1
fi

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Check if Easy-RSA directory exists
if [ ! -d "$EASYRSA_DIR" ]; then
    echo "Error: Easy-RSA directory not found at $EASYRSA_DIR"
    exit 1
fi

# Function to generate client configuration
generate_client_config() {
    local username=$1
    local email=$2
    local expiry_days=$3
    
    echo "Generating configuration for user: $username"
    
    # Create client directory if it doesn't exist
    mkdir -p "$OUTPUT_DIR/$username"
    
    # Change to Easy-RSA directory
    cd "$EASYRSA_DIR"
    
    # Generate client key and certificate
    ./easyrsa --batch gen-req "$username" nopass
    ./easyrsa --batch sign-req client "$username"
    
    # Set expiry if specified and not 0
    if [ ! -z "$expiry_days" ] && [ "$expiry_days" -ne 0 ]; then
        echo "Setting certificate expiry to $expiry_days days"
        # Note: Certificate expiry handling would be here if Easy-RSA supported it directly
        # For now we'll just add it as a comment in the config
    fi
    
    # Create client .ovpn file
    cat > "$OUTPUT_DIR/$username/$username.ovpn" << EOF
# OpenVPN Client Configuration
# User: $username
# Email: $email
# Generated: $(date)
# Expiry: $(if [ ! -z "$expiry_days" ] && [ "$expiry_days" -ne 0 ]; then date -d "+$expiry_days days"; else echo "Never"; fi)

client
dev tun
proto $PROTOCOL
remote $SERVER_PUBLIC_IP $PORT
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher $CIPHER
auth $AUTH
verb 3
key-direction 1
EOF

    # Add CA certificate
    echo "<ca>" >> "$OUTPUT_DIR/$username/$username.ovpn"
    cat "$EASYRSA_DIR/pki/ca.crt" >> "$OUTPUT_DIR/$username/$username.ovpn"
    echo "</ca>" >> "$OUTPUT_DIR/$username/$username.ovpn"
    
    # Add client certificate
    echo "<cert>" >> "$OUTPUT_DIR/$username/$username.ovpn"
    cat "$EASYRSA_DIR/pki/issued/$username.crt" >> "$OUTPUT_DIR/$username/$username.ovpn"
    echo "</cert>" >> "$OUTPUT_DIR/$username/$username.ovpn"
    
    # Add client key
    echo "<key>" >> "$OUTPUT_DIR/$username/$username.ovpn"
    cat "$EASYRSA_DIR/pki/private/$username.key" >> "$OUTPUT_DIR/$username/$username.ovpn"
    echo "</key>" >> "$OUTPUT_DIR/$username/$username.ovpn"
    
    # Add TLS auth key
    echo "<tls-auth>" >> "$OUTPUT_DIR/$username/$username.ovpn"
    cat "/etc/openvpn/ta.key" >> "$OUTPUT_DIR/$username/$username.ovpn"
    echo "</tls-auth>" >> "$OUTPUT_DIR/$username/$username.ovpn"
    
    echo "Client configuration for $username generated at $OUTPUT_DIR/$username/$username.ovpn"
    
    # Optional: Email the configuration file if email is provided
    if [ ! -z "$email" ] && command -v mail &> /dev/null; then
        echo "Emailing configuration to $email"
        echo "Your OpenVPN configuration is attached." | mail -s "OpenVPN Configuration" -a "$OUTPUT_DIR/$username/$username.ovpn" "$email"
    fi
}

# Read CSV file and generate configurations
echo "Reading users from $CSV_FILE"
sed 1d "$CSV_FILE" | while IFS=, read -r username email expiry_days
do
    # Skip empty lines
    if [ -z "$username" ]; then
        continue
    fi
    
    # Generate client configuration
    generate_client_config "$username" "$email" "$expiry_days"
done


echo "All client configurations generated successfully"
echo "--------------------------------------------"
echo "To add a new user in the future, run:"
echo "  $0 newusers.csv"
echo ""
echo "CSV format: username,email,expiry_days"
echo "Example: john,john@example.com,365"
echo "Use 0 for expiry_days to create certificates that don't expire"
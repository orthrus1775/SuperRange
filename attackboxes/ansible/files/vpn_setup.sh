#!/bin/bash

# OpenVPN Server Setup Script for Ubuntu
# Run this script as root

# Exit on error
set -e

# Default values for command-line parameters
DEFAULT_PRIVATE_NETWORK="192.168.0.0 255.255.255.0"

# Parse command-line parameters
PRIVATE_NETWORK=${1:-$DEFAULT_PRIVATE_NETWORK}

# Variables - customize these
PUBLIC_IP=$(curl -s ifconfig.me)
PORT=1194
PROTOCOL=udp
DNS1="8.8.8.8"
DNS2="8.8.4.4"
CIPHER="AES-256-GCM"
AUTH="SHA256"
DH_KEY_SIZE=2048
RSA_KEY_SIZE=2048
CLIENT_NAME="client1"

echo "Setting up OpenVPN server with private network route: $PRIVATE_NETWORK"

# Update system
echo "Updating system packages..."
apt update
apt upgrade -y
echo "127.0.0.1 $(hostname)" | sudo tee -a /etc/hosts

# Install OpenVPN and Easy-RSA
echo "Installing OpenVPN and Easy-RSA..."
apt install -y openvpn easy-rsa iptables-persistent

# Setup Easy-RSA directory
echo "Setting up Easy-RSA..."
mkdir -p /etc/openvpn/easy-rsa
cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa/
cd /etc/openvpn/easy-rsa

# Initialize PKI
echo "Initializing PKI..."
./easyrsa init-pki

# Build CA
echo "Building CA (Certificate Authority)..."
./easyrsa --batch --req-cn="OpenVPN-CA" build-ca nopass

# Generate server certificate and key
echo "Generating server certificate and key..."
./easyrsa --batch gen-req server nopass
./easyrsa --batch sign-req server server

# Generate Diffie-Hellman parameters
echo "Generating Diffie-Hellman parameters (this may take a while)..."
./easyrsa gen-dh

# Generate TLS-Auth key
echo "Generating TLS-Auth key..."
openvpn --genkey secret /etc/openvpn/ta.key

# Move certificates and keys to OpenVPN directory
echo "Moving certificates and keys to OpenVPN directory..."
cp pki/ca.crt /etc/openvpn/
cp pki/issued/server.crt /etc/openvpn/
cp pki/private/server.key /etc/openvpn/
cp pki/dh.pem /etc/openvpn/

# Create server config
echo "Creating server configuration..."
cat > /etc/openvpn/server.conf << EOF
port $PORT
proto $PROTOCOL
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS $DNS1"
push "dhcp-option DNS $DNS2"
push "route $PRIVATE_NETWORK"  # Private network route from command-line parameter
keepalive 10 120
cipher $CIPHER
auth $AUTH
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3
tls-auth ta.key 0
EOF

# Enable IP forwarding
echo "Enabling IP forwarding..."
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-openvpn.conf
sysctl --system

# Configure firewall (using ufw)
echo "Configuring firewall..."
apt install -y ufw
ufw allow ssh
ufw allow $PORT/$PROTOCOL
ufw allow from 10.8.0.0/24

# Get the primary network interface
NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
ufw allow in on $NIC
ufw allow out on $NIC
ufw allow in on tun0
ufw allow out on tun0

# Parse the network address and netmask from the PRIVATE_NETWORK variable
NETWORK_ADDRESS=$(echo $PRIVATE_NETWORK | cut -d' ' -f1)
NETMASK=$(echo $PRIVATE_NETWORK | cut -d' ' -f2)

# Setup NAT for routing
echo "Setting up NAT..."
cat > /etc/ufw/before.rules << EOF
# NAT table rules
*nat
:POSTROUTING ACCEPT [0:0]
# Allow traffic from OpenVPN client to the internet
-A POSTROUTING -s 10.8.0.0/24 -o $NIC -j MASQUERADE
COMMIT
EOF

ufw default deny incoming
ufw default allow outgoing
ufw --force enable

# Add iptables rules for the private network
echo "Adding iptables rules for private network routing..."
iptables -A FORWARD -i tun0 -o $NIC -d $NETWORK_ADDRESS/$NETMASK -j ACCEPT
iptables -A FORWARD -i $NIC -o tun0 -s $NETWORK_ADDRESS/$NETMASK -j ACCEPT

# Make iptables rules persistent
netfilter-persistent save

# Generate client configuration
echo "Generating client configuration..."
mkdir -p /etc/openvpn/clients/$CLIENT_NAME
./easyrsa --batch gen-req $CLIENT_NAME nopass
./easyrsa --batch sign-req client $CLIENT_NAME

# Create client .ovpn file
echo "Creating client .ovpn file..."
cat > /etc/openvpn/clients/$CLIENT_NAME/$CLIENT_NAME.ovpn << EOF
client
dev tun
proto $PROTOCOL
remote $PUBLIC_IP $PORT
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

# Add CA, cert, key and tls-auth to client config
echo "<ca>" >> /etc/openvpn/clients/$CLIENT_NAME/$CLIENT_NAME.ovpn
cat pki/ca.crt >> /etc/openvpn/clients/$CLIENT_NAME/$CLIENT_NAME.ovpn
echo "</ca>" >> /etc/openvpn/clients/$CLIENT_NAME/$CLIENT_NAME.ovpn

echo "<cert>" >> /etc/openvpn/clients/$CLIENT_NAME/$CLIENT_NAME.ovpn
cat pki/issued/$CLIENT_NAME.crt >> /etc/openvpn/clients/$CLIENT_NAME/$CLIENT_NAME.ovpn
echo "</cert>" >> /etc/openvpn/clients/$CLIENT_NAME/$CLIENT_NAME.ovpn

echo "<key>" >> /etc/openvpn/clients/$CLIENT_NAME/$CLIENT_NAME.ovpn
cat pki/private/$CLIENT_NAME.key >> /etc/openvpn/clients/$CLIENT_NAME/$CLIENT_NAME.ovpn
echo "</key>" >> /etc/openvpn/clients/$CLIENT_NAME/$CLIENT_NAME.ovpn

echo "<tls-auth>" >> /etc/openvpn/clients/$CLIENT_NAME/$CLIENT_NAME.ovpn
cat /etc/openvpn/ta.key >> /etc/openvpn/clients/$CLIENT_NAME/$CLIENT_NAME.ovpn
echo "</tls-auth>" >> /etc/openvpn/clients/$CLIENT_NAME/$CLIENT_NAME.ovpn

# Start OpenVPN service
echo "Starting OpenVPN service..."
systemctl enable openvpn@server
systemctl start openvpn@server

echo "OpenVPN server setup complete!"
echo "Client configuration file is located at: /etc/openvpn/clients/$CLIENT_NAME/$CLIENT_NAME.ovpn"
echo "Transfer this file securely to your client device to connect to the VPN."
echo "Private network route configured: $PRIVATE_NETWORK"
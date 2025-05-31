#!/bin/bash

sudo apt update
DEBIAN_FRONTEND=noninteractive sudo apt install -y openvpn easy-rsa iptables-persistent wget curl git expect
echo "127.0.0.1 $(hostname)" | sudo tee -a /etc/hosts
wget -O openvpn-install.sh https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
chmod +x openvpn-install.sh
sed -i 's/read -rp "DNS \[1-12\]: " -e -i 11 DNS/read -rp "DNS \[1-12\]: " -e -i 9 DNS/' openvpn-install.sh
sed -i 's/read -rp "Client name: " -e CLIENT/read -rp "Client name: " -e -i C2LAB CLIENT/' openvpn-install.sh
# CLIENT_NAME="test"
# PUBLIC_IP=$(curl -s ifconfig.me)


expect << EOF
spawn sudo ./openvpn-install.sh
expect "IP address:" { send "\r" }
expect "Public IPv4 address or hostname:" { send "\r" }
expect "Do you want to enable IPv6 support" { send "\r" }
expect "Port choice" { send "\r" }
expect "Protocol" { send "\r" }
expect "DNS" { send "\r" }
expect "Enable compression" { send "\r" }
expect "Customize encryption settings" { send "\r" }
expect "Press any key to continue" { send "\r" }
expect "Client name:" { send "\r" }
expect "Select an option" { send "\r" }
expect eof
EOF

# Enable IP forwarding temporarily
sudo sysctl -w net.ipv4.ip_forward=1

# Make it permanent by editing /etc/sysctl.conf
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf

# Enable NAT for traffic from tun0 to eth0
sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE

# Allow forwarding from tun0 to eth0
sudo iptables -A FORWARD -i tun0 -o eth0 -j ACCEPT

# Allow return traffic
sudo iptables -A FORWARD -i eth0 -o tun0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Install iptables-persistent
sudo apt update
sudo apt install iptables-persistent

# Save current rules
sudo iptables-save | sudo tee /etc/iptables/rules.v4

echo 'push "route 192.168.111.0 255.255.255.192"' | sudo tee -a /etc/openvpn/server.conf

sudo systemctl restart openvpn@server
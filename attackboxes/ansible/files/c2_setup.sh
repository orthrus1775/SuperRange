#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

git clone https://github.com/its-a-feature/Mythic.git
cd Mythic/
sudo ./install_docker_ubuntu.sh
sudo make
sudo ./mythic-cli config set ALLOWED_IP_BLOCKS "0.0.0.0/0,::/0,192.168.111.0/24,10.8.0.0/24"
sudo ./mythic-cli config set NGINX_USE_IPV6 "false"
sudo ./mythic-cli config set REBUILD_ON_START "false"
sudo ./mythic-cli install github https://github.com/MythicC2Profiles/http
sudo ./mythic-cli install github https://github.com/MythicC2Profiles/tcp
sudo ./mythic-cli install github https://github.com/MythicC2Profiles/smb
sudo ./mythic-cli install github https://github.com/MythicAgents/Apollo
#sudo ./mythic-cli install github https://github.com/MythicAgents/merlin 
sudo ./mythic-cli install github https://github.com/MythicAgents/service_wrapper.git
sudo ./mythic-cli install github https://github.com/MythicAgents/forge.git
sudo ./mythic-cli start
cat .env | grep "ADMIN_"
IP=$(ip a | grep 'inet 192\.168\.' | awk '{print $2}' | cut -d'/' -f1)  
USERNAME=$(cat .env | grep "ADMIN_" | grep "MYTHIC_ADMIN_USER" | awk -F"=" '{print $2}' | tr -d '"')
PASSWORD=$(cat .env | grep "ADMIN_" | grep "MYTHIC_ADMIN_PASSWORD" | awk -F"=" '{print $2}' | tr -d '"')
echo -e "${GREEN}Mythic deployed...${NC}"
echo -e "Login at ${YELLOW}http://$IP:7443${NC}"
echo -e "Username: ${YELLOW}$USERNAME${NC}"
echo -e "Password: ${YELLOW}$PASSWORD${NC}"

cat > ~/mythic_logon.sh << 'EOF'
#!/bin/bash
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
cd /home/attacker/Mythic
IP=$(ip a | grep 'inet 192\.168\.' | awk '{print $2}' | cut -d'/' -f1)  
USERNAME=$(cat .env | grep "ADMIN_" | grep "MYTHIC_ADMIN_USER" | awk -F"=" '{print $2}' | tr -d '"')
PASSWORD=$(cat .env | grep "ADMIN_" | grep "MYTHIC_ADMIN_PASSWORD" | awk -F"=" '{print $2}' | tr -d '"')
echo -e "${GREEN}Mythic Logon Information...${NC}"
echo -e "Login at ${YELLOW}https://$IP:7443${NC}"
echo -e "Username: ${YELLOW}$USERNAME${NC}"
echo -e "Password: ${YELLOW}$PASSWORD${NC}"
EOF

chmod +x ~/mythic_logon.sh  

cd ~
curl https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > msfinstall
chmod +x msfinstall
sudo ./msfinstall

git clone https://github.com/BishopFox/sliver.git
cd sliver
make
mkdir bins
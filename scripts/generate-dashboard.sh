#!/bin/bash
# generate-dashboard.sh - Generate a dashboard for all ranges

# NEEDS TO BE FIXED IN THE FUTURE

set -e # Exit on any error

# Check if arguments are provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <range1> <range2> ... <base-dir>"
    exit 1
fi

# Extract the base directory from the last argument
BASE_DIR="${@: -1}"

# Get ranges (all arguments except the last one)
RANGES=("${@:1:$#-1}")

echo "Generating dashboard for ranges: ${RANGES[*]}"
echo "Base directory: $BASE_DIR"

# Create dashboard directory
DASHBOARD_DIR="./dashboard"
mkdir -p "$DASHBOARD_DIR"

# Generate dashboard HTML
cat > "${DASHBOARD_DIR}/index.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GOAD Multi-Range Dashboard</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            color: #333;
        }
        h1, h2, h3 {
            color: #2c3e50;
        }
        .dashboard {
            margin-top: 20px;
        }
        .range-card {
            border: 1px solid #ddd;
            border-radius: 5px;
            padding: 15px;
            margin-bottom: 20px;
            background-color: #f9f9f9;
        }
        .range-card h2 {
            margin-top: 0;
            border-bottom: 1px solid #ddd;
            padding-bottom: 10px;
        }
        .section {
            margin-bottom: 15px;
        }
        .section h3 {
            margin-bottom: 10px;
        }
        .status {
            display: inline-block;
            padding: 3px 8px;
            border-radius: 3px;
            font-size: 14px;
            font-weight: bold;
        }
        .status-deployed {
            background-color: #d4edda;
            color: #155724;
        }
        .status-failed {
            background-color: #f8d7da;
            color: #721c24;
        }
        .status-pending {
            background-color: #fff3cd;
            color: #856404;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 15px;
        }
        th, td {
            padding: 8px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #f2f2f2;
        }
        .command {
            background-color: #f8f8f8;
            padding: 5px;
            border-radius: 3px;
            font-family: monospace;
        }
        .commands-list {
            max-height: 200px;
            overflow-y: auto;
            border: 1px solid #ddd;
            border-radius: 3px;
            padding: 10px;
            background-color: #fff;
        }
        .footer {
            margin-top: 30px;
            text-align: center;
            font-size: 14px;
            color: #666;
        }
    </style>
</head>
<body>
    <h1>GOAD Multi-Range Dashboard</h1>
    <p>Generated: $(date)</p>
    
    <div class="dashboard">
EOF

# Add each range to the dashboard
for RANGE in "${RANGES[@]}"; do
    RANGE_DIR="${BASE_DIR}/${RANGE}"
    CONFIG_FILE="${RANGE_DIR}/range-config.json"
    GOAD_SUMMARY="${RANGE_DIR}/goad-summary.txt"
    UBUNTU_SUMMARY="${RANGE_DIR}/ubuntu-summary.txt"
    UBUNTU_OUTPUT="${RANGE_DIR}/ubuntu-output.json"
    
    # Skip if config file doesn't exist
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Skipping range $RANGE - config file not found"
        continue
    fi
    
    # Load configuration
    RANGE_NUM=$(jq -r '.range_number' "$CONFIG_FILE")
    AWS_REGION=$(jq -r '.aws_region' "$CONFIG_FILE")
    GOAD_CIDR=$(jq -r '.goad_cidr' "$CONFIG_FILE")
    UBUNTU_SUBNET=$(jq -r '.ubuntu_subnet' "$CONFIG_FILE")
    ENABLE_DESKTOP=$(jq -r '.enable_desktop' "$CONFIG_FILE")
    INSTALL_RDP=$(jq -r '.install_rdp' "$CONFIG_FILE")
    
    # Start range card
    cat >> "${DASHBOARD_DIR}/index.html" <<EOF
        <div class="range-card">
            <h2>Range: ${RANGE} (#${RANGE_NUM})</h2>
            
            <div class="section">
                <h3>Configuration</h3>
                <table>
                    <tr>
                        <th>AWS Region</th>
                        <td>${AWS_REGION}</td>
                    </tr>
                    <tr>
                        <th>GOAD Network</th>
                        <td>${GOAD_CIDR}</td>
                    </tr>
                    <tr>
                        <th>Ubuntu Network</th>
                        <td>${UBUNTU_SUBNET}</td>
                    </tr>
                    <tr>
                        <th>Desktop Environment</th>
                        <td>$([ "$ENABLE_DESKTOP" == "true" ] && echo "Enabled" || echo "Disabled")</td>
                    </tr>
                    <tr>
                        <th>RDP Access</th>
                        <td>$([ "$INSTALL_RDP" == "true" ] && echo "Enabled" || echo "Disabled")</td>
                    </tr>
                </table>
            </div>
EOF

    # Add GOAD section if available
    if [ -f "$GOAD_SUMMARY" ]; then
        # Check deployment status from deployment-status.json
        GOAD_STATUS="Unknown"
        if [ -f "deployment-status.json" ]; then
            GOAD_STATUS=$(jq -r ".ranges[\"$RANGE\"].goad_status // \"Unknown\"" deployment-status.json)
        fi
        
        cat >> "${DASHBOARD_DIR}/index.html" <<EOF
            <div class="section">
                <h3>GOAD-Light Environment <span class="status status-$([ "$GOAD_STATUS" == "deployed" ] && echo "deployed" || echo "failed")">${GOAD_STATUS}</span></h3>
                <table>
                    <tr>
                        <th>Parent Domain</th>
                        <td>sevenkingdoms.local</td>
                    </tr>
                    <tr>
                        <th>Child Domain</th>
                        <td>north.sevenkingdoms.local</td>
                    </tr>
                    <tr>
                        <th>Servers</th>
                        <td>
                            <ul>
                                <li>DC1 (kingslanding): ${GOAD_CIDR%.*}.10</li>
                                <li>DC2 (winterfell): ${GOAD_CIDR%.*}.11</li>
                                <li>SRV (castelblack): ${GOAD_CIDR%.*}.22</li>
                            </ul>
                        </td>
                    </tr>
                    <tr>
                        <th>Credentials</th>
                        <td>Username: Administrator<br>Password: Password123!</td>
                    </tr>
                </table>
                
                <h4>Public Access</h4>
                <div class="commands-list">
EOF

        # Extract public IPs from GOAD instances file
        GOAD_INSTANCES="${RANGE_DIR}/goad-instances.json"
        if [ -f "$GOAD_INSTANCES" ]; then
            IPS=$(jq -r '.[][] | select(.[3][0] != null) | "\(.[3][0]): \(.[2])"' "$GOAD_INSTANCES")
            if [ -n "$IPS" ]; then
                echo "                    <ul>" >> "${DASHBOARD_DIR}/index.html"
                while IFS= read -r LINE; do
                    echo "                        <li>${LINE}</li>" >> "${DASHBOARD_DIR}/index.html"
                done <<< "$IPS"
                echo "                    </ul>" >> "${DASHBOARD_DIR}/index.html"
            else
                echo "                    <p>No public IPs available.</p>" >> "${DASHBOARD_DIR}/index.html"
            fi
        else
            echo "                    <p>GOAD instances information not available.</p>" >> "${DASHBOARD_DIR}/index.html"
        fi
        
        cat >> "${DASHBOARD_DIR}/index.html" <<EOF
                </div>
                
                <h4>Documentation</h4>
                <a href="${RANGE}/docs/index.html" target="_blank">View GOAD Documentation</a>
            </div>
EOF
    else
        cat >> "${DASHBOARD_DIR}/index.html" <<EOF
            <div class="section">
                <h3>GOAD-Light Environment <span class="status status-pending">Not Deployed</span></h3>
                <p>GOAD-Light has not been deployed for this range yet.</p>
            </div>
EOF
    fi
    
    # Add Ubuntu section if available
    if [ -f "$UBUNTU_OUTPUT" ]; then
        # Check deployment status from deployment-status.json
        UBUNTU_STATUS="Unknown"
        if [ -f "deployment-status.json" ]; then
            UBUNTU_STATUS=$(jq -r ".ranges[\"$RANGE\"].ubuntu_status // \"Unknown\"" deployment-status.json)
        fi
        
        cat >> "${DASHBOARD_DIR}/index.html" <<EOF
            <div class="section">
                <h3>Ubuntu Servers <span class="status status-$([ "$UBUNTU_STATUS" == "deployed" ] && echo "deployed" || echo "failed")">${UBUNTU_STATUS}</span></h3>
                
                <h4>Server Information</h4>
                <table>
                    <tr>
                        <th>Server</th>
                        <th>Private IP</th>
                        <th>Public IP</th>
                    </tr>
EOF

        # Add server information
        PRIVATE_IPS=$(jq -r '.private_ips.value[]' "$UBUNTU_OUTPUT")
        PUBLIC_IPS=$(jq -r '.public_ips.value[]' "$UBUNTU_OUTPUT")
        
        i=1
        while IFS= read -r PRIVATE_IP <&3 && IFS= read -r PUBLIC_IP <&4; do
            cat >> "${DASHBOARD_DIR}/index.html" <<EOF
                    <tr>
                        <td>Ubuntu ${i}</td>
                        <td>${PRIVATE_IP}</td>
                        <td>${PUBLIC_IP}</td>
                    </tr>
EOF
            i=$((i+1))
        done 3< <(echo "$PRIVATE_IPS") 4< <(echo "$PUBLIC_IPS")
        
        cat >> "${DASHBOARD_DIR}/index.html" <<EOF
                </table>
                
                <h4>SSH Access</h4>
                <div class="commands-list">
EOF

        # Add SSH commands
        SSH_COMMANDS=$(jq -r '.ssh_commands.value[]' "$UBUNTU_OUTPUT")
        if [ -n "$SSH_COMMANDS" ]; then
            echo "                    <ul>" >> "${DASHBOARD_DIR}/index.html"
            while IFS= read -r CMD; do
                echo "                        <li><code class=\"command\">${CMD}</code></li>" >> "${DASHBOARD_DIR}/index.html"
            done <<< "$SSH_COMMANDS"
            echo "                    </ul>" >> "${DASHBOARD_DIR}/index.html"
        else
            echo "                    <p>No SSH commands available.</p>" >> "${DASHBOARD_DIR}/index.html"
        fi
        
        cat >> "${DASHBOARD_DIR}/index.html" <<EOF
                </div>
EOF

        # Add RDP information if enabled
        if [ "$INSTALL_RDP" == "true" ]; then
            cat >> "${DASHBOARD_DIR}/index.html" <<EOF
                <h4>RDP Access</h4>
                <div class="commands-list">
                    <ul>
EOF

            # Add RDP commands
            RDP_COMMANDS=$(jq -r '.rdp_commands.value[]' "$UBUNTU_OUTPUT")
            while IFS= read -r CMD; do
                echo "                        <li>${CMD}</li>" >> "${DASHBOARD_DIR}/index.html"
            done <<< "$RDP_COMMANDS"
            
            cat >> "${DASHBOARD_DIR}/index.html" <<EOF
                    </ul>
                </div>
EOF
        fi
        
        cat >> "${DASHBOARD_DIR}/index.html" <<EOF
            </div>
EOF
    else
        cat >> "${DASHBOARD_DIR}/index.html" <<EOF
            <div class="section">
                <h3>Ubuntu Servers <span class="status status-pending">Not Deployed</span></h3>
                <p>Ubuntu servers have not been deployed for this range yet.</p>
            </div>
EOF
    fi
    
    # Add documentation link if available
    if [ -d "${RANGE_DIR}/docs" ]; then
        cat >> "${DASHBOARD_DIR}/index.html" <<EOF
            <div class="section">
                <h3>Documentation</h3>
                <ul>
                    <li><a href="${RANGE}/docs/index.html" target="_blank">View Full Documentation</a></li>
                    <li><a href="${RANGE}/docs/cheatsheet.md" target="_blank">Command Cheat Sheet</a></li>
                </ul>
            </div>
EOF
    fi
    
    # Close range card
    cat >> "${DASHBOARD_DIR}/index.html" <<EOF
        </div>
EOF
done

# Close dashboard HTML
cat >> "${DASHBOARD_DIR}/index.html" <<EOF
    </div>
    
    <div class="footer">
        <p>GOAD Multi-Range Deployment System - Generated on $(date)</p>
    </div>
</body>
</html>
EOF

# Create symlinks to range documentation
for RANGE in "${RANGES[@]}"; do
    if [ -d "${BASE_DIR}/${RANGE}/docs" ]; then
        ln -sf "${BASE_DIR}/${RANGE}/docs" "${DASHBOARD_DIR}/${RANGE}"
    fi
done

# Copy dashboard to base directory
cp -r "$DASHBOARD_DIR" "$BASE_DIR/"


echo "Dashboard generated at:"
echo "- ${DASHBOARD_DIR}/index.html"
echo "- ${BASE_DIR}/dashboard/index.html"
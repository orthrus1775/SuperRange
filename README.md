# GOAD Multi-Range Deployment System
Deploy 3 Ubuntu 24.04 t2.2xlarge Instances with Terraform
This system allows you to deploy and manage multiple independent ranges, each containing:
- A GOAD-Light environment (3 Windows servers running Active Directory)
- 3 Ubuntu servers pre-configured to interact with GOAD-Light

Each range is completely isolated with its own VPC, networks, and security groups, making it ideal for classroom or workshop environments where multiple students or teams need separate environments.  

![AINTMUCH](./davidbrandt.jpg)

## Prerequisites

- AWS account with appropriate permissions
- AWS CLI installed and configured
- Terraform installed
- Git installed
- JQ installed (for JSON processing)

## Initial Setup

Before using the system, run the setup script to make files executable and fix any line ending issues:

```bash
chmod +x setup.sh
./setup.sh
```

This script:
- Sets execute permissions on all script files
- Fixes line ending issues (in case files were modified on Windows)
- Checks for required dependencies
- Creates necessary directories

## Directory Structure

```
.
├── deploy-all-ranges.sh    # Main deployment script
├── destroy-all-ranges.sh   # Main destruction script
├── deployment-status.json  # Deployment status tracking
├── ranges/                 # Contains all range deployments
│   ├── range1/             # Range 1 files
│   │   ├── goad/           # Cloned GOAD repository
│   │   ├── ubuntu-servers/ # Terraform for Ubuntu servers
│   │   ├── docs/           # Range documentation
│   │   └── range-config.json # Range configuration
│   ├── range2/             # Range 2 files
│   └── ...
├── dashboard/              # Dashboard for all ranges
│   └── index.html          # Main dashboard file
└── scripts/                # Helper scripts
    ├── deploy-goad.sh      # Deploy GOAD for a range
    ├── deploy-ubuntu.sh    # Deploy Ubuntu servers for a range
    ├── destroy-goad.sh     # Destroy GOAD for a range
    ├── destroy-ubuntu.sh   # Destroy Ubuntu servers for a range
    ├── generate-config.sh  # Generate range configuration
    ├── generate-docs.sh    # Generate range documentation
    └── generate-dashboard.sh # Generate dashboard for all ranges
```
## Deployment Steps

To deploy multiple ranges, run:

```bash
./deploy-all-ranges.sh
```

This will:
1. Prompt you for the AWS key pair to use and the AWS region
2. Clone the GOAD repository for each range
3. Automatically retrieve the latest Windows Server 2019 AMI for your selected region
4. Update all Windows AMI IDs in the GOAD configuration files
5. Deploy GOAD-Light with a Windows 10 workstation for each range
6. Deploy three Ubuntu servers for each range
7. Generate documentation and a dashboard for all ranges

### Destroying Ranges

To destroy all ranges, run:

```bash
./destroy-all-ranges.sh
```

This will prompt for confirmation before destroying each range.

### Accessing the Dashboard

After deployment, a dashboard is generated at:

```
./dashboard/index.html
```

Open this file in a web browser to see all ranges, their status, and access information.

## Range Configuration

Each range has its own configuration file at `ranges/<range-id>/range-config.json`. This includes:

* Range identifier and number
* AWS region and availability zone
* Network CIDR blocks
* Desktop environment configuration
* RDP access configuration
* Tags for resource identification

## Range Components

### GOAD-Light Environment

The GOAD-Light environment consists of:

* **DC1 (kingslanding)**: Primary Domain Controller for sevenkingdoms.local
* **DC2 (winterfell)**: Domain Controller for north.sevenkingdoms.local
* **SRV (castelblack)**: Server with services (MSSQL, IIS, etc.)
* **WS01 (desktop)**: Windows 10 workstation joined to the domain (deployed with the -e ws01 flag)

### Ubuntu Servers

Each range includes 3 Ubuntu 24.04 servers with:

* Pre-installed penetration testing tools
* Desktop environment (if enabled)
* RDP access (if enabled)
* Pre-configured to connect to GOAD-Light

## Customization

To customize the number or configuration of ranges:

1. Edit `deploy-all-ranges.sh` to modify the `RANGES` array
2. Adjust specific configuration in `scripts/generate-config.sh`
3. For more significant changes, modify the deployment scripts directly

## Network Configuration

Each range has its own isolated networking:

* All servers use the same 192.168.X.0/24 network (where X is the range number)
* GOAD servers use IPs 192.168.X.10, 192.168.X.11, 192.168.X.22, and the WS01 workstation uses 192.168.X.31
* Ubuntu servers use IPs 192.168.X.80, 192.168.X.81, and 192.168.X.82
* Even though the Ubuntu servers are in a separate VPC, they use IP addresses in the GOAD network range to ensure connectivity

## Security Considerations

* Each range has its own security groups
* All servers have default credentials (Administrator/Password123! for GOAD, ubuntu/Password123! for Ubuntu)
* These are meant for educational purposes only - do not use in production

## Troubleshooting

If deployment fails:

1. Check the logs in the range directory
2. Fix the issue and rerun the deployment script
3. Use the dashboard to see the status of each range

### Line Ending Issues

If you encounter "bad interpreter" errors or other script execution problems, run the setup script again:

```bash
./setup.sh
```

This will fix any line ending issues that may have been introduced when editing files on Windows.

## Clean Up

After finishing with the ranges, run:

```bash
./destroy-all-ranges.sh
```

To ensure all AWS resources are properly destroyed.

## Note on GOAD-Light

GOAD-Light is a project by Orange Cyberdefense that creates a vulnerable Active Directory environment for security testing. This system uses GOAD-Light as a base and extends it with Ubuntu servers for a complete penetration testing environment.

For more information on GOAD-Light, see: https://github.com/Orange-Cyberdefense/GOAD  

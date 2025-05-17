# Customizing Attack Boxes

The Attack Boxes extension provides extensive customization options through Terraform variables. This allows you to tailor the attack boxes to your specific needs without modifying the core code.

## How to Customize

1. Create a `custom.tfvars` file by copying the provided `default.tfvars` file:

   ```bash
   cp extensions/attackboxes/providers/aws/default.tfvars extensions/attackboxes/providers/aws/custom.tfvars
   ```

2. Edit the `custom.tfvars` file to set your desired values.

3. When installing the extension, specify the custom variable file:

   ```bash
   ./goad.sh -t install_extension -e attackboxes -var-file extensions/attackboxes/providers/aws/custom.tfvars
   ```

## Available Customization Options

### General Configuration

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `attackbox_count` | Number of attack boxes to deploy | 3 |
| `attackbox_base_name` | Base name for the attack boxes | "attackbox" |
| `attackbox_username` | Username for the attack boxes | "ubuntu" |
| `attackbox_password` | Password for the attack boxes (Azure) | "AttackBox2024!" |
| `attackbox_ip_start` | Starting last octet for IP addresses | 51 |

### AWS Configuration

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `attackbox_instance_type` | Instance type for AWS | "t2.medium" |
| `attackbox_disk_size` | Root disk size in GB | 20 |
| `attackbox_disk_type` | Root disk type | "gp3" |
| `attackbox_ami_id` | Specific AMI ID (leave empty for auto-detection) | "" |
| `attackbox_ami_owner` | Owner ID for AMI lookup | "099720109477" (Canonical) |
| `attackbox_ami_name_pattern` | Name pattern for AMI lookup | "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" |

### Azure Configuration

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `attackbox_azure_size` | VM size for Azure | "Standard_B2s" |
| `attackbox_azure_publisher` | Publisher for Azure image | "Canonical" |
| `attackbox_azure_offer` | Offer for Azure image | "0001-com-ubuntu-server-noble" |
| `attackbox_azure_sku` | SKU for Azure image | "24_04-lts-gen2" |
| `attackbox_azure_version` | Version for Azure image | "latest" |

### Proxmox Configuration

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `attackbox_proxmox_clone` | Template to clone for Proxmox | "Ubuntu2404_x64" |
| `attackbox_proxmox_cores` | Number of CPU cores | 2 |
| `attackbox_proxmox_memory` | Amount of memory in MB | 4096 |

### Tools and Software

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `attackbox_additional_tools` | Additional APT packages to install | List of pentesting tools |
| `attackbox_additional_python_tools` | Python packages to install via pip | List of Python pentesting tools |
| `attackbox_git_repos` | Git repositories to clone | List of common security repos |

## Examples

### Create High-Performance Attack Boxes

```hcl
attackbox_count = 2
attackbox_instance_type = "t2.xlarge"
attackbox_disk_size = 50
attackbox_proxmox_cores = 4
attackbox_proxmox_memory = 8192
```

### Use a Specific AMI

```hcl
attackbox_ami_id = "ami-0123456789abcdef"
```

### Add Custom Tools

```hcl
attackbox_additional_tools = [
  "netcat-openbsd",
  "hashcat",
  "john",
  "hydra",
  "metasploit-framework",
  "sqlmap",
  "gobuster",
  "dirb",
  "aircrack-ng",
  "dsniff"
]

attackbox_git_repos = [
  {
    name = "PowerSploit"
    url  = "https://github.com/PowerShellMafia/PowerSploit.git"
  },
  {
    name = "mimikatz"
    url  = "https://github.com/gentilkiwi/mimikatz.git"
  },
  {
    name = "my-custom-tools"
    url  = "https://github.com/username/my-custom-tools.git"
  }
]
```

### Change IP Addresses

```hcl
attackbox_ip_start = 100  # This will use IPs 100, 101, 102, etc.
```

## Note on AMI Selection

For AWS deployments, you can either:

1. Let the extension automatically find the latest Ubuntu 24.04 AMI by leaving `attackbox_ami_id` empty
2. Specify a particular AMI ID for full control

To find available Ubuntu 24.04 AMIs in your region:

```bash
aws ec2 describe-images --owners 099720109477 --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" --query "reverse(sort_by(Images, &CreationDate))[0].[ImageId,Name]" --output text
```

Or use the AWS Systems Manager Parameter Store:

```bash
aws ssm get-parameters --names /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id --query "Parameters[0].Value" --output text
```

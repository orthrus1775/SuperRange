# Attack Boxes GOAD Extension

This extension adds three Ubuntu 24.04 attack boxes to the GOAD lab environment. These machines are configured with offensive security tools and are ready for performing penetration testing against the Active Directory environment.

## Installation

To install this extension, follow these steps:

1. Place the extension files in the `extensions/attackboxes` directory of your GOAD installation.

2. Use the GOAD CLI to install the extension:

```bash
# First, list available extensions
./goad.sh -t list_extensions

# Then install the attackboxes extension
./goad.sh -t install_extension -e attackboxes
```

Alternatively, you can install the extension during the initial GOAD setup:

```bash
./goad.sh -t install -l GOAD -p <provider> -e attackboxes
```

Replace `<provider>` with your desired provider (aws, azure, vmware, virtualbox, or proxmox).

## Attack Box Information

The attack boxes are configured with the following settings:

| Attack Box Name | IP Address | Specs |
|-----------------|------------|-------|
| attackbox-1     | {{ip_range}}.81 | 2 CPUs, 4GB RAM, 20GB Disk |
| attackbox-2     | {{ip_range}}.82 | 2 CPUs, 4GB RAM, 20GB Disk |
| attackbox-3     | {{ip_range}}.83 | 2 CPUs, 4GB RAM, 20GB Disk |

## Accessing the Attack Boxes

### From the Jumpbox

If you're using AWS or Azure, you can access the attack boxes through the jumpbox:

```bash
# SSH to the jumpbox first
ssh -i ssh_keys/ubuntu-jumpbox.pem ubuntu@<jumpbox-public-ip>

# Then from the jumpbox, SSH to any of the attack boxes
ssh ubuntu@{{ip_range}}.51
ssh ubuntu@{{ip_range}}.52
ssh ubuntu@{{ip_range}}.53
```

### Direct Access (VirtualBox/VMware)

If you're using VirtualBox or VMware, you can access the attack boxes directly through the forwarded ports:

```bash
# For attackbox-1
ssh ubuntu@localhost -p 2251

# For attackbox-2
ssh ubuntu@localhost -p 2252

# For attackbox-3
ssh ubuntu@localhost -p 2253
```

## Pre-installed Tools

Each attack box comes with the following security and penetration testing tools:

### Networking Tools
- net-tools (ifconfig, netstat)
- tcpdump
- wireshark
- nmap

### Pentesting Tools
- Metasploit Framework
- SQLMap
- Hashcat
- John the Ripper
- Hydra
- Gobuster and Dirb
- Impacket Suite
- BloodHound
- CrackMapExec

### Useful Utilities
- Git (with popular security repositories like PowerSploit and Mimikatz)
- Python 3 with pip
- Custom command aliases for common pentesting tasks

## Usage Examples

The attack boxes are ideal for:

1. **Active Directory Enumeration**:
   ```bash
   nmap-quick 192.168.56.0/24
   crackmapexec smb 192.168.56.0/24
   ```

2. **Running Bloodhound**:
   ```bash
   cd /opt/attack-tools/BloodHound
   ```

3. **Password Cracking**:
   ```bash
   john --wordlist=/usr/share/wordlists/rockyou.txt hashes.txt
   ```

4. **Exploiting Vulnerabilities**:
   ```bash
   msfconsole
   ```

## Customization

You can customize the attack boxes by editing the appropriate provider files:

- For AWS: `providers/aws/linux.tf`
- For Azure: `providers/azure/linux.tf`
- For VirtualBox/VMware: `providers/virtualbox/Vagrantfile.rb` or `providers/vmware/Vagrantfile.rb`
- For Proxmox: `providers/proxmox/linux.tf`

The Ansible role at `ansible/roles/attackbox-setup` handles the software installation and configuration of the attack boxes. You can modify the tasks to install additional tools or configure specific settings.

## Troubleshooting

If you encounter issues with the extension, check the following:

1. Ensure the provider-specific files are correctly configured for your environment.
2. Verify that the Ubuntu 24.04 image/box is available for your provider.
3. Check the Ansible logs for any errors during provisioning.
4. Some security tools might fail to install; check the logs and install them manually if needed.

For AWS and Azure deployments, you may need to update the AMI or image references to match the available Ubuntu 24.04 images in your region.
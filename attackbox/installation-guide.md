# Ubuntu Servers GOAD Extension

This extension adds three Ubuntu 24.04 servers to the GOAD lab environment. These servers are configured to work with the GOAD infrastructure and can be used for various purposes such as:

- Running additional services
- Testing tools and exploits
- Target practice for penetration testing
- Setting up monitoring or defensive tools

## Installation

To install this extension, follow these steps:

1. Place the extension files in the `extensions/ubuntu-servers` directory of your GOAD installation.

2. Use the GOAD CLI to install the extension:

```bash
# First, list available extensions
./goad.sh -t list_extensions

# Then install the ubuntu-servers extension
./goad.sh -t install_extension -e ubuntu-servers
```

Alternatively, you can install the extension during the initial GOAD setup:

```bash
./goad.sh -t install -l GOAD -p <provider> -e ubuntu-servers
```

Replace `<provider>` with your desired provider (aws, azure, vmware, virtualbox, or proxmox).

## Server Information

The Ubuntu servers are configured with the following settings:

| Server Name | IP Address | Specs |
|-------------|------------|-------|
| ubuntu-server-1 | {{ip_range}}.51 | 2 CPUs, 4GB RAM, 20GB Disk |
| ubuntu-server-2 | {{ip_range}}.52 | 2 CPUs, 4GB RAM, 20GB Disk |
| ubuntu-server-3 | {{ip_range}}.53 | 2 CPUs, 4GB RAM, 20GB Disk |

## Accessing the Servers

### From the Jumpbox

If you're using AWS or Azure, you can access the Ubuntu servers through the jumpbox:

```bash
# SSH to the jumpbox first
ssh -i ssh_keys/ubuntu-jumpbox.pem ubuntu@<jumpbox-public-ip>

# Then from the jumpbox, SSH to any of the Ubuntu servers
ssh ubuntu@{{ip_range}}.51
ssh ubuntu@{{ip_range}}.52
ssh ubuntu@{{ip_range}}.53
```

### Direct Access (VirtualBox/VMware)

If you're using VirtualBox or VMware, you can access the servers directly through the forwarded ports:

```bash
# For ubuntu-server-1
ssh ubuntu@localhost -p 2251

# For ubuntu-server-2
ssh ubuntu@localhost -p 2252

# For ubuntu-server-3
ssh ubuntu@localhost -p 2253
```

## Installed Software

Each Ubuntu server comes pre-configured with the following tools:

- net-tools (ifconfig, netstat, etc.)
- tcpdump
- wireshark
- nmap
- curl, wget
- git
- vim, htop
- Python 3 with pip
- Ansible
- DNS utilities

## Customization

You can customize the server configurations by editing the appropriate provider files:

- For AWS: `providers/aws/linux.tf`
- For Azure: `providers/azure/linux.tf`
- For VirtualBox/VMware: `providers/virtualbox/Vagrantfile.rb` or `providers/vmware/Vagrantfile.rb`
- For Proxmox: `providers/proxmox/linux.tf`

The Ansible role at `ansible/roles/ubuntu-setup` handles the software installation and configuration of the servers. You can modify the tasks to suit your needs.

## Troubleshooting

If you encounter issues with the extension, check the following:

1. Ensure the provider-specific files are correctly configured for your environment.
2. Verify that the Ubuntu 24.04 image/box is available for your provider.
3. Check the Ansible logs for any errors during provisioning.
4. Ensure the servers have network connectivity to the rest of the GOAD environment.

For AWS and Azure deployments, you may need to update the AMI or image references to match the available Ubuntu 24.04 images in your region.

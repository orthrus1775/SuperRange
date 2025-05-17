# Attackboxes configuration in GOAD-compatible format
"attackbox1" = {
  name               = "attackbox1"
  linux_sku          = "24_04-lts-gen2"
  linux_version      = "latest"
  ami                = "ami-0158cbc3c8e9ef377"
  private_ip_address = "{{ip_range}}.80"
  password           = "suppaP@ssw0rd$"
  size               = "t2.2xlarge"
  disk_size          = 60  # Disk size in GB
}
"attackbox2" = {
  name               = "attackbox1"
  linux_sku          = "24_04-lts-gen2"
  linux_version      = "latest"
  ami                = "ami-0158cbc3c8e9ef377"
  private_ip_address = "{{ip_range}}.81"
  password           = "suppaP@ssw0rd$"
  size               = "t2.2xlarge"
  disk_size          = 60  # Disk size in GB
}
"attackbox3" = {
  name               = "attackbox1"
  linux_sku          = "24_04-lts-gen2"
  linux_version      = "latest"
  ami                = "ami-0158cbc3c8e9ef377"
  private_ip_address = "{{ip_range}}.82"
  password           = "suppaP@ssw0rd$"
  size               = "t2.2xlarge"
  disk_size          = 60  # Disk size in GB
}
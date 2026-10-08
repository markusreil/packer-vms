packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.4"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "pm_api_url" {
  type = string
  default = "https://pve4.home.arpa:8006/api2/json"
}
variable "pve4_packer_token_id" {
  type = string
  default = "packer@pve!packer-token"
}
variable "pve4_packer_token_secret" {
  type = string
  default = "your-api-token-secret"
}

source "proxmox-iso" "debian-docker" {
  proxmox_url              = var.pm_api_url
  username                 = var.pve4_packer_token_id
  token                    = var.pve4_packer_token_secret
  insecure_skip_tls_verify = true

  node                 = "pve4"
  vm_id                = "9000"
  vm_name              = "debian-13-template"
  template_description = "Debian 13 Template"

  machine  = "q35"
  cores    = var.cpus
  memory   = var.memory
  os       = "l26"
  bios     = "ovmf"

  scsi_controller = "virtio-scsi-single"

  efi_config {
    efi_storage_pool  = "local-lvm"  # Replace with your Proxmox storage pool name
    efi_type           = "4m"         # Standard modern 4MB EFI type
    pre_enrolled_keys = false         # Set to true if you need Secure Boot keys pre-loaded
  }

  qemu_agent = true

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  disks {
    disk_size         = var.disk_size_proxmox
    storage_pool      = "local-lvm" # Change to your Proxmox storage name
    type              = "scsi"
    discard           = true
  }

  # Ensure the Debian Netinst ISO is uploaded to your Proxmox 'local' storage first
  boot_iso {
    iso_file = "local:iso/debian-13.6.0-amd64-netinst.iso"
    unmount = true
  }

  http_content     = {
    "/debian.cfg" = templatefile("../../http/debian.cfg.pkrtpl.hcl", {
      username = var.linux_user_name
      password = var.linux_user_password
    })
  }
  boot_command     = [
    "<wait>",
    "c",
    "<wait><wait>",
    "linux /install.amd/vmlinuz ",
    "fb=false ",
    "debconf/priority=critical ",
    "auto=true ",
    "ipv6.disable=1 ",
    "netcfg/get_hostname=debian-template ",
    "grub-installer/force-efi-extra-removable=true ",
    "url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/debian.cfg ",
    "<enter>",
    "initrd /install.amd/initrd.gz<enter>",
    "boot<enter>"
  ]

  ssh_username     = var.linux_user_name
  ssh_password     = var.linux_user_password
  ssh_timeout      = "15m"
}

build {
  sources = ["source.proxmox-iso.debian-docker"]

  # Bash script block to install Docker natively
  provisioner "shell" {
    inline = [
      "echo '>>> Installing Basics...'",
      "sudo apt-get update",
      "sudo apt-get install -y ca-certificates curl gnupg",
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "sudo apt-get update",

      "echo '>>> Cleaning up network machine-id to prevent DHCP conflicts...'",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id",
      "sudo ln -s /etc/machine-id /var/lib/dbus/machine-id"
    ]
  }
}

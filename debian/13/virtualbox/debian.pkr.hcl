packer {
  required_plugins {
    virtualbox = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/virtualbox"
    }
  }
}

variable "iso_url" {
  type    = string
  default = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.7.0-amd64-netinst.iso"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:a7ef94ac2fb9a7fec454552abd629b7cc9d5155c886165a45649f5ce6167e355"
}

variable "vm_name" {
  type    = string
  default = "packer-debian-13"
}

source "virtualbox-iso" "debian" {
  guest_os_type = "Debian_64"
  vm_name       = var.vm_name
  firmware      = "efi"

  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  cpus   = var.cpus
  memory = var.memory

  hard_drive_interface = "sata"
  disk_size            = var.disk_size_vbox
  iso_interface        = "sata"
  output_directory     = "output/debian/13/virtualbox"
  keep_registered      = true

  http_content = {
    "/debian.cfg" = templatefile("../../http/debian.cfg.pkrtpl.hcl", {
      username = var.linux_user_name
      password = var.linux_user_password
    })
  }
  boot_command = [
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

  ssh_username = var.linux_user_name
  ssh_password = var.linux_user_password
  ssh_timeout  = "30m"

  shutdown_command = "echo '${var.linux_user_password}' | sudo -S shutdown -P now"

  guest_additions_mode = "upload"
  vboxmanage = [
    ["modifyvm", "{{ .Name }}", "--graphicscontroller", "vmsvga"],
    ["modifyvm", "{{ .Name }}", "--audio", "none"]
  ]
}

build {
  sources = ["source.virtualbox-iso.debian"]

  provisioner "shell" {
    inline = [
      "echo '>>> Installing base tools...'",
      "sudo apt-get update",
      "sudo apt-get install -y ca-certificates curl gnupg",
      "echo '>>> Sanitizing machine-id...'",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id",
      "sudo ln -s /etc/machine-id /var/lib/dbus/machine-id"
    ]
  }
}

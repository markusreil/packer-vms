packer {
  required_plugins {
    virtualbox = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/virtualbox"
    }
  }
}

# Rolling release: the ISO URL tracks the latest monthly snapshot, so the
# checksum is intentionally left at "none" (a pinned hash would rot every
# month). The installed system is fully up to date at build time.
variable "iso_url" {
  type    = string
  default = "https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso"
}

variable "iso_checksum" {
  type    = string
  default = "none"
}

variable "vm_name" {
  type    = string
  default = "packer-arch"
}

source "virtualbox-iso" "arch" {
  guest_os_type = "ArchLinux_64"
  vm_name       = var.vm_name
  firmware      = "efi"

  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  cpus   = var.cpus
  memory = var.memory

  hard_drive_interface = "sata"
  disk_size            = var.disk_size_vbox
  iso_interface        = "sata"
  output_directory     = "output/arch/rolling/virtualbox"
  keep_registered      = true
  guest_additions_mode = "disable"

  # archiso auto-logs in as root on tty1. Set a password and bring up sshd
  # so Packer can connect; the installer script runs over that session.
  boot_command = [
    "<wait60s>",
    "echo '${var.root_user_name}:${var.root_user_password}' | chpasswd<enter>",
    "systemctl start sshd<enter>"
  ]

  ssh_username = var.root_user_name
  ssh_password = var.root_user_password
  ssh_timeout  = "30m"

  shutdown_command = "systemctl poweroff"

  vboxmanage = [
    ["modifyvm", "{{ .Name }}", "--graphicscontroller", "vmsvga"],
    ["modifyvm", "{{ .Name }}", "--audio", "none"]
  ]
}

build {
  sources = ["source.virtualbox-iso.arch"]

  # Installs Arch to disk and finishes it in place (machine-id, pacman
  # cache). No reboot: the live VM is shut down after this and the disk
  # exported, so the installed system boots for the first time outside
  # the build.
  provisioner "shell" {
    environment_vars = [
      "ROOT_USER=${var.root_user_name}",
      "ROOT_PASSWORD=${var.root_user_password}",
      "LINUX_USER=${var.linux_user_name}",
      "LINUX_PASSWORD=${var.linux_user_password}"
    ]
    script = "arch/http/install.sh"
  }
}

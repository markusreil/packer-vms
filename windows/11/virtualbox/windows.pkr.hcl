packer {
  required_plugins {
    virtualbox = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/virtualbox"
    }
    windows-update = {
      version = ">= 0.15.0"
      source  = "github.com/rgl/windows-update"
    }
  }
}

# Plain Windows 11 ISO from Microsoft's download page
# (https://www.microsoft.com/software-download/windows11). No stable direct
# link, so download once into repo-root iso/ (gitignored) and either drop
# it there (the default below) or pass -var 'iso_url=<url-or-path>'. Unactivated installs run indefinitely with
# a watermark; no key is baked in. Checksum stays "none": the file is
# local and MS re-cuts the media periodically, so a pinned hash would rot.
variable "iso_url" {
  type    = string
  default = "iso/Windows11_Client_x64_en-us_26300_9457.iso"
}

variable "iso_checksum" {
  type    = string
  default = "none"
}

variable "vm_name" {
  type    = string
  default = "packer-windows-11"
}

# The shared linux user becomes the Windows local admin (name/password from
# root common.pkrvars.hcl); no new variables needed.
source "virtualbox-iso" "windows" {
  guest_os_type = "Windows11_64"
  vm_name       = var.vm_name
  firmware      = "efi"

  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  cpus   = var.cpus
  memory = 4096

  hard_drive_interface = "sata"
  # Windows needs real headroom: the applied 26H2 Pro image alone is ~18GB,
  # plus pagefile and update scratch during specialize. The shared 20GB
  # default (fine for Debian/Arch) fills up and kills Setup with the
  # "restarted unexpectedly" dialog. 64GB is also Microsoft's minimum.
  disk_size            = 65536
  iso_interface        = "sata"
  output_directory     = "output/windows/11/virtualbox"
  keep_registered      = true

  # Stock Win11 enforces TPM/Secure Boot/CPU checks; the answer file
  # bypasses them via registry keys, so no virtual TPM is needed here.
  # No boot_command either: setup reads Autounattend.xml from the extra
  # CD automatically.
  cd_content = {
    "Autounattend.xml" = templatefile("../../http/autounattend.xml.pkrtpl.hcl", {
      username = var.linux_user_name
      password = var.linux_user_password
    })
  }

  # Boot the installer DVD first (disk is empty), and press a key at the
  # "Press any key to boot from CD or DVD" prompt, which EFI shows.
  # boot_wait is short on purpose: the prompt appears seconds after power-on
  # and expires fast; stray enters during EFI init are harmless.
  boot_wait    = "2s"
  boot_command = ["<enter><wait3s><enter><wait3s><enter>"]

  communicator   = "winrm"
  winrm_username = var.linux_user_name
  winrm_password = var.linux_user_password
  winrm_timeout  = "60m"

  shutdown_command = "shutdown /s /t 5 /f /d p:4:1 /c \"Packer Shutdown\""

  guest_additions_mode = "disable"

  vboxmanage = [
    ["modifyvm", "{{ .Name }}", "--graphicscontroller", "vmsvga"],
    ["modifyvm", "{{ .Name }}", "--audio", "none"],
    ["modifyvm", "{{ .Name }}", "--boot1", "dvd"],
    ["modifyvm", "{{ .Name }}", "--boot2", "disk"],
  ]
}

build {
  sources = ["source.virtualbox-iso.windows"]

  provisioner "windows-update" {
    search_criteria = "IsInstalled=0"
  }

  # Ansible-ready WinRM, re-asserted at the end of the build: clones get a
  # new NIC identity and Windows may re-classify the network as Public,
  # which silently drops the WinRM firewall exception. Private first,
  # then the listener/auth/transport Packer and Ansible both rely on.
  provisioner "powershell" {
    inline = [
      "Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private",
      "Enable-PSRemoting -Force -SkipNetworkProfileCheck",
      "winrm quickconfig -q",
      "winrm set winrm/config/service/auth '@{Basic=\"true\"}'",
      "winrm set winrm/config/service '@{AllowUnencrypted=\"true\"}'",
    ]
  }
}

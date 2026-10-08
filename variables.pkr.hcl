# Variable declarations shared by every template in this repo. Packer has no
# include mechanism, so each template dir symlinks this file in as
# variables.pkr.hcl (e.g. debian/13/virtualbox/variables.pkr.hcl ->
# ../../../variables.pkr.hcl). Passwords intentionally have NO defaults:
# root common.pkrvars.hcl is their only source. Tuning knobs keep defaults
# below.
variable "root_user_name" {
  type    = string
  default = "root"
}

variable "root_user_password" {
  type      = string
  sensitive = true
}

variable "linux_user_name" {
  type    = string
  default = "linux"
}

variable "linux_user_password" {
  type      = string
  sensitive = true
}

variable "disk_size_vbox" {
  type    = number
  default = 20000
}

variable "disk_size_proxmox" {
  type    = string
  default = "20G"
}

variable "cpus" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 2048
}

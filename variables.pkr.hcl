# Variable declarations shared by every template in this repo. Packer has no
# include mechanism, so each template dir symlinks this file in as
# variables.pkr.hcl (e.g. debian/13/virtualbox/variables.pkr.hcl ->
# ../../../variables.pkr.hcl). Passwords intentionally have NO defaults:
# root common.pkrvars.hcl is their only source. Tuning knobs keep defaults
# below.
variable "ssh_password" {
  type      = string
  sensitive = true
}

# Only the Arch template consumes this (its installer script takes root and
# user passwords as separate inputs); declared here so its value also lives
# only in common.pkrvars.hcl.
variable "arch_password" {
  type      = string
  sensitive = true
}

variable "cpus" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 2048
}

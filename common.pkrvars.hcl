# Shared non-secret build defaults, applied to every template by run.sh
# (`-var-file common.pkrvars.hcl`). The single source for login passwords;
# declarations live in root variables.pkr.hcl (symlinked into templates).
#
# Real secrets stay in ~/.config/packer/secrets.pkrvars.hcl, which run.sh
# loads AFTER this file, so it always wins on conflicts.
#
# Every shared knob except root_user_name lives here: change a value once
# and all templates pick it up on the next build.

# Credentials. root_user_name stays "root" (fixed in variables.pkr.hcl);
# its password and the linux user's name/password are set here.
root_user_password  = "changeme"
linux_user_password = "changeme"
linux_user_name     = "linux"

# Disk sizes. VirtualBox wants megabytes (number), Proxmox wants a
# size string with unit (e.g. "20G"), hence two variables.
disk_size_vbox    = 20000
disk_size_proxmox = "20G"

# VM tuning. Bump per build via -var if a template needs more headroom.
cpus   = 2
memory = 2048

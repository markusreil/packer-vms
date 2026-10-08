# Shared non-secret build defaults, applied to every template by run.sh
# (`-var-file common.pkrvars.hcl`). The single source for login passwords;
# declarations live in root variables.pkr.hcl (symlinked into templates).
#
# Real secrets stay in ~/.config/packer/secrets.pkrvars.hcl, which run.sh
# loads AFTER this file, so it always wins on conflicts.
ssh_password  = "changeme"
arch_password = "changeme"

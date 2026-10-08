# Debian

Unattended Debian installs via preseed (`http/debian.cfg.pkrtpl.hcl`, rendered
with the shared login password at build time), shared by all
Debian versions and hosts in this repo.

## Versions

| Version | Preseed        | Hosts                          |
| ------- | -------------- | ------------------------------ |
| 13      | `http/debian.cfg.pkrtpl.hcl` | `13/proxmox`, `13/virtualbox` |

## Preseed notes (`http/debian.cfg.pkrtpl.hcl`)

- Locale `en_US`, keymap `us`, hostname `debian-template`, domain
  `home.arpa`, UTC clock.
- User `debian` / password `changeme` (shared default from root
  `common.pkrvars.hcl`; change post-clone or via provisioner),
  passwordless sudo via `late_command` → `/etc/sudoers.d/debian`.
- EFI layout: 512MB EFI partition, no swap, rest on ext4 `/`.
- One merged `pkgsel/include`: `openssh-server qemu-guest-agent sudo curl
  ca-certificates` (duplicate keys overwrite, so keep it single).
- Non-free + non-free-firmware + contrib enabled; IPv6 disabled at install.

## Building

From repo root:

```bash
./run.sh debian/13/proxmox
./run.sh debian/13/virtualbox
```

## Adding a version (e.g. 14)

1. `cp -r 13 14`, bump ISO name/version in each host's `.pkr.hcl`.
2. Reuse `http/debian.cfg.pkrtpl.hcl` unless the installer needs new keys.
3. Add the row to the table above.

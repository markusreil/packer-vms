# Arch

Rolling-release Arch installs for VirtualBox, built from the monthly
archiso snapshot. There are no version directories; `rolling/` always
tracks the latest ISO and the installed system is fully up to date at
build time.

## Layout

```text
arch/
├── README.md                 # this file
├── http/install.sh           # unattended installer, runs in the live ISO
└── rolling/
    └── virtualbox/arch.pkr.hcl
```

## How it works

Unlike Debian there is no preseed: the template boots archiso (which
auto-logs in as root), sets a root password and starts sshd via
`boot_command`, then runs `http/install.sh` over SSH. That script wipes
`/dev/sda` (512MB EFI + ext4 root, no swap), pacstraps a minimal system
with GRUB `--removable`, creates the `arch` user with passwordless sudo,
and finishes the install in place. There is deliberately no reboot: the
ISO stays attached, so rebooting would boot back into archiso. Packer
shuts the live VM down after provisioning and exports the disk, which
boots the installed system for the first time outside the build.

Guest additions come from the `virtualbox-guest-utils-nox` package
(`vboxservice` enabled; no X stack on a server template), so the builder's
`guest_additions_mode` stays `disable`.

## Building

From repo root:

```bash
./run.sh arch/rolling/virtualbox
./run.sh -f arch/rolling/virtualbox   # also clears old output / VM
```

Validate without building:

```bash
packer validate arch/rolling/virtualbox
```

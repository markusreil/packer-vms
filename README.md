# packer-vms

Build-on-demand VM templates with HashiCorp Packer, across distros and
virtualization hosts. Each distro owns its unattended-install config once;
each host under it owns only its builder template.

## Layout

```text
.
├── README.md               # this file (generic usage)
├── AGENTS.md               # agent working agreements
├── common.pkrvars.hcl       # shared non-secret defaults (login passwords)
├── run.sh                  # build helper (secrets always from $HOME)
├── debian/
│   ├── README.md           # distro specifics (preseed, versions, hosts)
│   ├── http/debian.cfg.pkrtpl.hcl  # shared Debian preseed template,
│   └── 13/
│       ├── proxmox/debian.pkr.hcl
│       └── virtualbox/debian.pkr.hcl
├── arch/
│   ├── README.md           # rolling-release notes
│   ├── http/install.sh     # unattended installer, runs in the live ISO
│   └── rolling/
│       └── virtualbox/arch.pkr.hcl
```

Adding a distro: copy the `debian/` shape (`README.md`, `http/`, `<ver>/`).
Adding a host for a version: add `<distro>/<ver>/<host>/` reusing the
distro's `http/` dir. Adding a version: add `<distro>/<ver>/`.

## Secrets (always in home, never in repo)

- `common.pkrvars.hcl` holds shared non-secret defaults (login passwords);
  `run.sh` applies it to every template automatically.
- `~/.config/packer/secrets.pkrvars.hcl` holds tokens/passwords, loaded
  after it so real secrets always win.
- Templates declare secret variables with dummy defaults; the var-file
  overrides them at build time. `git` must never see real secrets
  (see `.gitignore`).

## Building

Always run from the repo root so relative `http_content` paths resolve:

```bash
./run.sh debian/13/proxmox
./run.sh debian/13/virtualbox
```

`run.sh` usage (full help: `./run.sh --help`):

```bash
./run.sh [-f] <template-dir> [extra packer args...]
# e.g. ./run.sh debian/13/proxmox -only='*.debian*'
# -f removes previous output and unregisters an existing VirtualBox VM first
```

Validate without building (dummy secret):

```bash
packer validate -var-file=common.pkrvars.hcl -var 'pve4_packer_token_secret=dummy' debian/13/proxmox
packer validate -var-file=common.pkrvars.hcl debian/13/virtualbox
packer validate -var-file=common.pkrvars.hcl arch/rolling/virtualbox
```

## Hosts

### Proxmox (remote API host, setup once per site)

Create the least-privilege service user/token Packer builds use.
Secrets live in `~/.config/packer/secrets.pkrvars.hcl`, never in the repo.

```shell
pveum user add packer@pve --password "ChooseAStrongPassword"

pveum role add PackerRole --privs "VM.Allocate VM.Clone VM.Config.CDROM \
  VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory \
  VM.Config.Network VM.Config.Options VM.Console VM.PowerMgmt VM.Audit \
  VM.GuestAgent.Audit VM.GuestAgent.Unrestricted \
  Datastore.AllocateSpace Datastore.Audit Sys.Audit Sys.Modify SDN.Use"

pveum acl modify /sdn/zones --tokens 'packer@pve!packer-token' --roles PackerRole
```

`~/.config/packer/secrets.pkrvars.hcl` (example):

```hcl
pm_api_url                 = "https://pve4.home.arpa:8006/api2/json"
pve4_packer_token_id       = "packer@pve!packer-token"
pve4_packer_token_secret   = "REDACTED"
```

Template defaults reference the `packer@pve` service user, not
`root@pam`. Node/storage/bridge/ISO stay per-template variables.

### VirtualBox (always `localhost`)

No API tokens, no var-file needed for credentials. Requirements on the
build machine:

- VirtualBox + Extension Pack installed.
- `packer` with the `virtualbox-iso` builder (bundled plugin).
- Templates download their ISO via `iso_url` (checksum pinned where the
  release is versioned; rolling Arch uses `none`).

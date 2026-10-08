# packer-vms

Build-on-demand VM templates with HashiCorp Packer, across distros and
virtualization hosts. Each distro owns its unattended-install config once;
each host under it owns only its builder template.

## Layout

```text
.
├── README.md               # this file (generic usage)
├── AGENTS.md               # agent working agreements
├── common.pkrvars.hcl       # shared non-secret defaults (login, disk, tuning)
├── variables.pkr.hcl       # shared declarations (symlinked into templates)
├── run.sh                  # build helper (secrets always from $HOME)
├── vm.sh                   # working-VM helper (clone, up, ssh, destroy)
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
- Password variables declare NO defaults and fail validation without
  a var-file; tuning knobs fall back to `variables.pkr.hcl` defaults.
  `git` must never see real secrets (see `.gitignore`).

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

## Working VMs (`vm.sh`)

Clone a `packer-*` template into a throwaway working VM (VirtualBox):

```bash
./vm.sh up                    # default name "dev", SSH on localhost:2222
./vm.sh -n dnstest -p 2223 up # custom name and SSH port
./vm.sh -n dnstest ssh        # ssh as linux@127.0.0.1
./vm.sh -n dnstest shutdown   # ACPI shutdown, power off after 60s
./vm.sh -n dnstest destroy    # delete the VM including its disk
./vm.sh -n dnstest status
./vm.sh list                  # all VMs with running state
```

On first `up` for a name, pick one of the registered `packer-*`
templates to clone; the SSH forward (`-p`) is (re)applied on every `up`.

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

No API tokens, but the shared var-file is still required (passwords have
no defaults). Requirements on the build machine:

- VirtualBox + Extension Pack installed.
- `packer` with the `virtualbox-iso` builder (bundled plugin).
- Templates download their ISO via `iso_url` (checksum pinned where the
  release is versioned; rolling Arch uses `none`).

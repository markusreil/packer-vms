# AGENTS.md

## Repo shape

Multi-distro, multi-host Packer library. Distro owns the unattended-install
config once; each `<distro>/<ver>/<host>/` owns only its builder template.

```text
.
├── README.md, AGENTS.md, run.sh, vm.sh, common.pkrvars.hcl, variables.pkr.hcl
├── debian/README.md, debian/http/debian.cfg.pkrtpl.hcl, debian/13/<host>/debian.pkr.hcl
└── arch/README.md, arch/http/install.sh, arch/rolling/virtualbox/arch.pkr.hcl
```

Shared declarations (`root_user_*`, `linux_user_*`, `disk_size_*`, `cpus`, `memory`)
live once in root `variables.pkr.hcl`, symlinked into each template dir.
Passwords have no defaults: values come only from `common.pkrvars.hcl`
(via `run.sh`); tuning knobs fall back to the file defaults.

## Working agreements

1. **Repo root is CWD** for every `packer`/`run.sh` invocation. `http_content`
   paths are relative to each template dir (e.g. `../../http/`).
2. **Secrets never enter the repo.** All tokens/passwords come from
   `~/.config/packer/secrets.pkrvars.hcl` via `-var-file`, loaded after
   root `common.pkrvars.hcl` (shared non-secret defaults like login
   passwords). Tuning knobs keep dummy defaults in `variables.pkr.hcl`.
3. **Preseed discipline** (`debian/http/*.pkrtpl.hcl`): debconf syntax is exact;
   never duplicate a key (last wins); keep `pkgsel/include` single.
4. **VirtualBox host is always localhost** — no credential variables.
5. **Proxmox defaults use the `packer@pve` service user**, not `root@pam`.
6. **Docs:** generic usage and host setup in root `README.md`; distro
   specifics in `<distro>/README.md`.
7. Validate by directory (so the symlinked `variables.pkr.hcl` loads),
   always with the shared var-file (passwords have no defaults),
   before handing off:
   `packer validate -var-file=common.pkrvars.hcl
   -var 'pve4_packer_token_secret=dummy' debian/13/proxmox`
   and `packer validate -var-file=common.pkrvars.hcl
   debian/13/virtualbox` (same shape for `arch/rolling/virtualbox`).

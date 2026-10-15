# Windows

Unattended Windows install via answer file
(`http/autounattend.xml.pkrtpl.hcl`, rendered with the shared username and
password at build time), shared by all Windows versions and hosts in this
repo. That user becomes the local admin; Packer connects back over WinRM.

## Versions

| Version | Answer file                        | Hosts            |
| ------- | ---------------------------------- | ---------------- |
| 11      | `http/autounattend.xml.pkrtpl.hcl` | `11/virtualbox`  |

Plain Windows 11 Pro, installed without a key: unactivated installs run
indefinitely with a settings watermark and no personalization, which is
fine for throwaway dev VMs. A key can be applied post-clone if needed.

## Building

Microsoft offers no stable direct ISO link. Download once from the
Windows 11 download page, then from repo root:

```bash
./run.sh windows/11/virtualbox -var 'iso_url=/path/to/iso'
```

## Answer-file notes (`http/autounattend.xml.pkrtpl.hcl`)

- Locale `en-US`, hostname `packer-windows`, UTC clock.
- EFI layout: 512MB EFI, 16MB MSR, rest on NTFS.
- Installs the `Windows 11 Pro` image from the multi-edition ISO.
- Bypasses the TPM/Secure Boot/CPU/RAM checks via LabConfig keys, so no
  virtual TPM is needed on the host.
- WinRM enabled with basic auth + unencrypted allowed (build network only),
  one-shot auto-logon for FirstLogonCommands.

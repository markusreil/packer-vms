# packer-debian

## Prepare proxmox

```shell
pveum user add packer@pve --password "ChooseAStrongPassword"
```

```shell
pveum role add PackerRole --privs "VM.Allocate VM.Clone VM.Config.CDROM \
  VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory \
  VM.Config.Network VM.Config.Options VM.Console VM.PowerMgmt VM.Audit \
  VM.GuestAgent.Audit VM.GuestAgent.Unrestricted \
  Datastore.AllocateSpace Datastore.Audit Sys.Audit Sys.Modify SDN.Use"
  
pveum acl modify /sdn/zones --tokens 'packer@pve!packer-token' --roles Pack
erRole
```


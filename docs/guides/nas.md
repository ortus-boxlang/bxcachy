---
title: Your NAS
order: 5
summary: Connect a Synology or any SMB or NFS share, mount it by itself, and back up to it.
---

# Your NAS

`bxrig nas` keeps every NAS you use: its address, the share, how to reach it, and the mount.

```bash
bxrig nas setup --yes                   # cifs-utils, nfs-utils, smbclient, avahi, rsync
bxrig nas discover                      # find NAS boxes on the network
bxrig nas add synology --host=ds920.local --user=luis --ask-password
bxrig nas shares synology
bxrig nas mount synology backups --yes  # ~/NAS/synology/backups
bxrig nas auto on synology backups --yes
bxrig nas test synology
bxrig nas use synology backups          # a place for bxrig backup data
```

- **Passwords** are typed hidden and kept in your keyring. SMB mounts are made by root (also at boot), so the password is also kept in `/etc/bxrig/nas/NAME.cred`, readable by root only; the plan tells you before it writes it. NFS needs no password.
- **The SMB version** is negotiated: the highest one the NAS and your kernel both support. Give `--vers=3.1.1` to choose.
- **Automatic mounts** are systemd `.mount` and `.automount` units: the share mounts the first time something opens it and lets go after ten idle minutes, so a sleeping NAS never blocks your login.
- **`nas sync NAME SRC --to=SHARE/PATH`** is a plain `rsync` mirror (photos, media). Nothing on the NAS is deleted unless you add `--delete`.
- **`nas test`** checks that the NAS answers, that your password works, that the share is mounted and writable, and how much space is free.

Not yet tried on a real Synology: share permissions in DSM, SMB signing and NFS export options. If a mount fails, `bxrig nas test NAME` says which step.

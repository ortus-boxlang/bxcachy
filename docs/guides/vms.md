---
title: Virtual machines
order: 4
summary: Windows and Linux desktops that run in containers, as many as you like.
---

# Virtual machines

`bxrig vm` runs full desktops in containers: Windows (the dockur/windows image) and Linux desktops (LinuxServer's webtop, a desktop in your browser). They use Podman, or Docker if you chose it with `bxrig db engine docker`.

```bash
bxrig vm doctor                          # is this machine ready? (KVM, groups, GPU, disk)
bxrig vm create linux dev                # a Ubuntu XFCE desktop called dev
bxrig vm create linux arch --tag=arch-kde --gpu=auto
bxrig vm create windows                  # asks which Windows
bxrig vm list                            # all of them: state, ports, disk used
bxrig vm open dev                        # starts it if needed and opens it
```

`create` shows a plan first; add `--yes` to do it. `--dry-run` never changes anything.

## Linux desktops

`bxrig vm versions linux` lists the tags: Ubuntu, Debian, Fedora and Arch with XFCE, KDE Plasma, MATE or i3 (plus LXQt on Ubuntu), and a small Alpine. The default is `ubuntu-xfce`. Make as many as you want; each gets its own port, data folder and password.

`vm open NAME` opens `https://127.0.0.1:PORT/` in your browser. The certificate is self-signed, so accept it once. The user is `bxrig`; show the password with `bxrig vm info NAME --show-password`.

**GPU** (optional): `--gpu=intel` or `--gpu=amd` passes `/dev/dri` in. `--gpu=nvidia` is supported too; it needs the NVIDIA driver 580 or newer and the NVIDIA container toolkit, and it is not available on the Alpine tags. `--gpu=auto` uses `/dev/dri` when the machine has it. `vm doctor` shows what your machine has.

## Windows

You pick the version when you create it:

| Choice | Size | Note |
|---|---|---|
| `11` Windows 11 Pro | 7.9 GB | the usual choice |
| `11l` Windows 11 LTSC | 4.7 GB | long-term servicing edition, fewer bundled apps |
| `11e` Windows 11 Enterprise | 6.6 GB | business edition |
| `10` Windows 10 Pro | 5.7 GB | older, for legacy needs |
| `10l` Windows 10 LTSC | 4.6 GB | long-term servicing edition |
| `tiny11` Tiny11 | 5.3 GB | **unofficial** stripped-down build from the community |
| `core11` Tiny11 Core | 3.0 GB | **unofficial**, the most stripped-down |
| `tiny10` Tiny10 | 3.6 GB | **unofficial** stripped-down Windows 10 |
| `2025`, `2022` Windows Server | 7.6, 6.0 GB | server editions |

`bxrig vm versions windows` shows all 25 (down to Windows 95 and ReactOS). In a script, pass `--version=VALUE`.

Windows installs itself the first time it starts: it downloads the ISO inside the container (3 to 8 GB) and takes a while. Watch it with `bxrig vm open NAME --web`. When it is ready, `bxrig vm open NAME` opens it with FreeRDP, with the clipboard shared and the window resizable. **You need your own Windows license.** The install uses generic trial keys that do not activate Windows.

Windows needs `/dev/kvm`: turn on virtualization in the firmware and put yourself in the `kvm` group. `vm doctor` tells you what is missing. Defaults: half your RAM (4 to 8 GB), half your cores, a 64 GB disk. Change them with `--ram`, `--cpus` and `--disk`.

## Where everything is

| What | Where |
|---|---|
| Disk and files of each VM | `~/.local/share/bxrig/vms/NAME` (`storage` for Windows, `config` for Linux) |
| The VM's record | `~/.config/bxrig/vms/NAME.json` |
| Its password | your keyring, as `BXRIG_VM_NAME_PASSWORD` (see `bxrig secrets`) |
| Shared folder | `~/Windows` (drive Z: in Windows) or `~/Shared` (inside the Linux desktop); `--share=PATH` or `--share=none` |
| App menu entry | `~/.local/share/applications/bxrig-vm-NAME.desktop` |
| The container images | in Podman or Docker (`podman image ls`) |

`bxrig vm size` shows how much disk each VM uses. Everything listens on `127.0.0.1` only.

## Stop, remove

```bash
bxrig vm stop dev
bxrig vm remove dev            # the container, its data, password and menu entry (it asks first)
bxrig vm remove dev --keep-data
```

Your shared folder is never deleted.

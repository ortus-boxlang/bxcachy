---
title: Files and folders
order: 2
summary: Where BxRig keeps things.
---

# Files and folders

| Path | What |
|---|---|
| `~/.local/bin/bxrig` | the program |
| `~/.config/bxrig/answers.json` | your wizard answers (mode 600, no secrets) |
| `~/.config/bxrig/shortcuts.json` | your shortcut changes |
| `~/.config/bxrig/runner.json` | launcher and menu program |
| `~/.config/bxrig/update.json` | update channel and notification setting |
| `~/.config/bxrig/skills.json` | the agent skills BxRig installed |
| `~/.config/bxrig/appearance.json` | what you chose in `bxrig appearance` (bar, dock, windows, font) |
| `~/.config/bxrig/display.json` | what you chose in `bxrig display` (scale, rotation, mirror, laptop panel) |
| `~/.config/bxrig/theme.json` | the current theme and mode |
| `~/.config/bxrig/theme/look.lua` | generated Hyprland window looks (gaps, corners, opacity); never edit |
| `~/.config/bxrig/theme/monitors.lua` | generated Hyprland monitor settings; never edit |
| `~/.config/bxrig/nas.json` | your NAS boxes (no passwords) |
| `~/.config/bxrig/backup.json` | backup places, what is backed up, retention, schedule (no keys) |
| `~/.local/share/bxrig/backups/config/` | your BxRig config snapshots |
| `/etc/bxrig/nas/NAME.cred` | the SMB credentials of a NAS, root only (mode 600) |
| `~/.config/systemd/user/bxrig-backup.{service,timer}` | the automatic file backup |
| `~/.config/bxrig/vms/` | one record per virtual machine |
| `/etc/systemd/logind.conf.d/50-bxrig-lid.conf` | what closing the lid does (`bxrig power lid`); remove it to go back to the defaults |
| `/etc/pam.d/sudo` and `.bxrig-backup` | one marked line per `bxrig security fingerprint\|fido2 on`; the backup is the original |
| `/etc/sudoers.d/50-bxrig-nopasswd` | passwordless sudo (`bxrig security passwordless-sudo on`) |
| `/etc/systemd/system/automatic-timezoned.service`, `/etc/geoclue/conf.d/90-bxrig-timezone.conf` | the automatic time zone (`bxrig time auto on`) |
| `~/.config/bxrig/plasma-panels/` | the Plasma panel layout and its backup |
| `~/.config/bxrig/welcome.html` | the getting-started page |
| `~/.config/hypr/bxrig.lua` | generated Hyprland module (never edit); `hyprland.lua` is yours |
| `~/.agents/skills/` | the agent skills store, linked into each agent |
| `~/.config/systemd/user/bxrig-*.service` | night shift, AirPlay, update check, cloud mounts |
| `~/.cache/bxrig/install.log` | the installer's log |

Every file BxRig writes goes through one safe writer: atomic replace, a backup, a journal, and a **drift** check. A file you changed is kept and reported as drifted. `bxrig config diff NAME` shows how it differs from what BxRig would write.

---
title: Files and folders
order: 2
summary: Where BxCachy keeps things.
---

# Files and folders

| Path | What |
|---|---|
| `~/.local/bin/bxcachy` | the program |
| `~/.config/bxcachy/answers.json` | your wizard answers (mode 600, no secrets) |
| `~/.config/bxcachy/shortcuts.json` | your shortcut changes |
| `~/.config/bxcachy/runner.json` | launcher and menu program |
| `~/.config/bxcachy/update.json` | update channel and notification setting |
| `~/.config/bxcachy/skills.json` | the agent skills BxCachy installed |
| `~/.config/bxcachy/appearance.json` | what you chose in `bxcachy appearance` (bar, dock, windows, font) |
| `~/.config/bxcachy/display.json` | what you chose in `bxcachy display` (scale, rotation, mirror, laptop panel) |
| `~/.config/bxcachy/theme.json` | the current theme and mode |
| `~/.config/bxcachy/theme/look.lua` | generated Hyprland window looks (gaps, corners, opacity); never edit |
| `~/.config/bxcachy/theme/monitors.lua` | generated Hyprland monitor settings; never edit |
| `~/.config/bxcachy/nas.json` | your NAS boxes (no passwords) |
| `~/.config/bxcachy/backup.json` | backup places, what is backed up, retention, schedule (no keys) |
| `~/.local/share/bxcachy/backups/config/` | your BxCachy config snapshots |
| `/etc/bxcachy/nas/NAME.cred` | the SMB credentials of a NAS, root only (mode 600) |
| `~/.config/systemd/user/bxcachy-backup.{service,timer}` | the automatic file backup |
| `~/.config/bxcachy/vms/` | one record per virtual machine |
| `/etc/systemd/logind.conf.d/50-bxcachy-lid.conf` | what closing the lid does (`bxcachy power lid`); remove it to go back to the defaults |
| `/etc/pam.d/sudo` and `.bxcachy-backup` | one marked line per `bxcachy security fingerprint\|fido2 on`; the backup is the original |
| `/etc/sudoers.d/50-bxcachy-nopasswd` | passwordless sudo (`bxcachy security passwordless-sudo on`) |
| `/etc/systemd/system/automatic-timezoned.service`, `/etc/geoclue/conf.d/90-bxcachy-timezone.conf` | the automatic time zone (`bxcachy time auto on`) |
| `~/.config/bxcachy/plasma-panels/` | the Plasma panel layout and its backup |
| `~/.config/bxcachy/welcome.html` | the getting-started page |
| `~/.config/hypr/bxcachy.lua` | generated Hyprland module (never edit); `hyprland.lua` is yours |
| `~/.agents/skills/` | the agent skills store, linked into each agent |
| `~/.config/systemd/user/bxcachy-*.service` | night shift, AirPlay, update check, cloud mounts |
| `~/.cache/bxcachy/install.log` | the installer's log |

Every file BxCachy writes goes through one safe writer: atomic replace, a backup, a journal, and a **drift** check. A file you changed is kept and reported as drifted. `bxcachy config diff NAME` shows how it differs from what BxCachy would write.

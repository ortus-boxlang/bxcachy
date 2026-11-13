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
| `~/.config/bxcachy/plasma-panels/` | the Plasma panel layout and its backup |
| `~/.config/bxcachy/welcome.html` | the getting-started page |
| `~/.config/hypr/bxcachy.lua` | generated Hyprland module (never edit); `hyprland.lua` is yours |
| `~/.agents/skills/` | the agent skills store, linked into each agent |
| `~/.config/systemd/user/bxcachy-*.service` | night shift, AirPlay, update check, cloud mounts |
| `~/.cache/bxcachy/install.log` | the installer's log |

Every file BxCachy writes goes through one safe writer: atomic replace, a backup, a journal, and a **drift** check. A file you changed is kept and reported as drifted. `bxcachy config diff NAME` shows how it differs from what BxCachy would write.

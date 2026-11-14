---
title: The control center
order: 2
summary: One menu for everything BxRig does, on your launcher, with search.
---

# The control center

`bxrig menu` (bound to `Super+Alt+M`) opens a menu on your launcher (Rofi, Walker, Wofi, Fuzzel or Vicinae: `bxrig runner set NAME`). It follows Omarchy's layout and adds a Develop section for what is ours.

| Section | What is in it |
|---|---|
| Search | Every entry of the menu as one flat list; type to filter, press Enter to run it. |
| Apps | Your installed apps. |
| Install | Any package from the repositories or the AUR, the catalog by group (AI, Development, Terminal, Gaming), web apps, virtual machines, fonts. |
| Remove | Packages, catalog apps, web apps, themes, virtual machines, agent skills. It asks first. |
| Appearance | Theme, mode, font, background, bar, dock, windows, animations. See [Appearance](appearance.md). |
| Trigger | Screenshots and recording, toggles (do not disturb, stay awake, night light), emoji, clipboard history, force quit, overview. |
| Setup | Power, Display, Defaults, Keyboard, Security, Time, DNS, Kernel, Cloud storage, Hardware. |
| Update | BxRig updates, the system update (a snapshot first), skills, re-apply appearance and display. |
| Develop | BoxLang, databases, virtual machines, containers, the editor. |
| Agent | Open an agent, the pull-down AI shell, sessions, local models, API keys. |
| Learn, About, System | Docs and cheat sheets, the status of this machine, lock, suspend, log out, reboot, shut down. |

Every entry is a command you can type: `bxrig menu items` lists them with the command each one runs, and `bxrig menu search TEXT` finds one. Entries that print something open in a terminal and wait for Enter; entries that need a choice (a theme, a font, a time zone, a monitor) ask you in the same menu.

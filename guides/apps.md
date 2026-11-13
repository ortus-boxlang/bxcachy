---
title: Apps and web apps
order: 4
summary: The catalog, one-click suites, defaults, and the extras around them.
---

# Apps and web apps

## The catalog

BxCachy knows about 280 apps and web apps in groups (development, terminal, AI, infrastructure, network, system, desktop, everyday, web apps, media, gaming). Each is **default** (installed by the wizard's Basic mode) or **optional**. Sources: official packages first (`pacman`), then the AUR (`yay`), Omarchy's packages, vendor installers and web apps.

```bash
bxcachy catalog list --group media
bxcachy catalog show strata
bxcachy install vlc heidisql --yes
bxcachy profile-install jvm --yes        # a ready-made set
```

In the wizard, **Basic** installs the recommended set; **Customize** lets you tick apps per category. Some entries only apply to one desktop (they say so).

## Web apps

A web app is a frameless window with its own launcher entry.

```bash
bxcachy web add Notion https://notion.so --yes
bxcachy web list
bxcachy web install google --yes         # Docs, Drive, Gmail, Calendar, Maps, Photos, YouTube...
bxcachy web install microsoft --yes      # Word, Excel, PowerPoint, Outlook, Teams, OneDrive
bxcachy web install apple --yes          # iCloud, Pages, Numbers, Keynote, Apple Music, Apple TV
```

The same three are in the wizard (Apps page) and the control center (Web apps).

## Defaults

```bash
bxcachy default show
bxcachy default browser brave --yes
bxcachy default terminal ghostty --yes
bxcachy default filemanager strata --yes
```

## Files and sharing

The default file manager is **Strata**; Dolphin is the alternative (`bxcachy dolphin doctor` checks it works outside Plasma). `bxcachy strata integrations` adds LocalSend and KDE Connect to Strata's *Send to* menu. `bxcachy quicklook PATH` previews a file with Kiview.

## More

| Area | Command |
|---|---|
| Dictation | `bxcachy dictation setup superwhisper\|voxtype --yes` |
| Databases | `bxcachy db list\|start ENGINE\|stop\|status\|logs` (Podman first; HeidiSQL and DBeaver are in the catalog) |
| Cloud storage as folders | `bxcachy cloud remotes\|configure\|mount NAME\|status` (RClone Browser is the GUI) |
| VPN | `bxcachy vpn nordvpn setup` |
| Containers | `bxcachy containers doctor\|socket enable\|docker-compat` |
| Editor | `bxcachy editor lazyvim` |
| GPU drivers | `bxcachy gpu doctor` |

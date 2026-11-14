---
title: Apps and web apps
order: 4
summary: The catalog, one-click suites, defaults, and the extras around them.
---

# Apps and web apps

## The catalog

BxRig knows about 280 apps and web apps in groups (development, terminal, AI, infrastructure, network, system, desktop, everyday, web apps, media, gaming). Each is **default** (installed by the wizard's Basic mode) or **optional**. Sources: official packages first (`pacman`), then the AUR (`yay`), Omarchy's packages, vendor installers and web apps.

```bash
bxrig catalog list --group media
bxrig catalog show strata
bxrig install vlc heidisql --yes
bxrig profile-install jvm --yes        # a ready-made set
```

In the wizard, **Basic** installs the recommended set; **Customize** lets you tick apps per category. Some entries only apply to one desktop (they say so).

## Web apps

A web app is a frameless window with its own launcher entry.

```bash
bxrig web add Notion https://notion.so --yes
bxrig web list
bxrig web install google --yes         # Docs, Drive, Gmail, Calendar, Maps, Photos, YouTube...
bxrig web install microsoft --yes      # Word, Excel, PowerPoint, Outlook, Teams, OneDrive
bxrig web install apple --yes          # iCloud, Pages, Numbers, Keynote, Apple Music, Apple TV
```

The same three are in the wizard (Apps page) and the control center (Web apps).

## Defaults

```bash
bxrig default show
bxrig default browser brave --yes
bxrig default terminal ghostty --yes
bxrig default filemanager strata --yes
```

## Files and sharing

The default file manager is **Strata**; Dolphin is the alternative (`bxrig dolphin doctor` checks it works outside Plasma). `bxrig strata integrations` adds LocalSend and KDE Connect to Strata's *Send to* menu. `bxrig quicklook PATH` previews a file with Kiview.

## More

| Area | Command |
|---|---|
| Dictation | `bxrig dictation setup superwhisper\|voxtype --yes` |
| Databases | `bxrig db list\|start ENGINE\|stop\|status\|logs` (Podman first; HeidiSQL and DBeaver are in the catalog) |
| Cloud storage as folders | `bxrig cloud remotes\|configure\|mount NAME\|status` (RClone Browser is the GUI) |
| VPN | `bxrig vpn nordvpn setup` |
| Containers | `bxrig containers doctor\|socket enable\|docker-compat` |
| Editor | `bxrig editor lazyvim` |
| GPU drivers | `bxrig gpu doctor` |

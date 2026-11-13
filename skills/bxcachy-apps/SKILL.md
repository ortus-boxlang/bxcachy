---
name: bxcachy-apps
description: "Use this skill when installing or choosing apps with BxCachy: the app catalog and profiles, web apps and the Google, Microsoft and Apple bundles, default browser, terminal and file manager, dictation, Quick Look, databases, cloud storage and the BoxLang developer tools."
---

# BxCachy: apps

- The catalog: `bxcachy catalog list|show ID|groups|check`. Install: `bxcachy install ID... [--yes]`, `bxcachy profile-install NAME`, `bxcachy install --shell=hyprland|plasma|all`. Sources: pacman, AUR (yay), Omarchy PKGBUILDs, vendor installer scripts, web apps.
- Web apps (frameless windows): `bxcachy web add NAME URL --yes`, `web list`, `web rm NAME`, `web install google|microsoft|apple|boxlang|all --yes`.
- Defaults: `bxcachy default show|browser ID|terminal ID|filemanager ID --yes`.
- Dictation: `bxcachy dictation setup superwhisper|voxtype --yes`. Quick Look: `bxcachy quicklook PATH`. Dolphin: `bxcachy dolphin doctor [--fix]`. Strata Send-to providers: `bxcachy strata integrations`.
- Databases (Podman first): `bxcachy db list|start ENGINE|stop|status|logs|remove|info`. Cloud storage as folders: `bxcachy cloud remotes|configure|mount NAME|unmount NAME|status`.
- BoxLang tools: `bxcachy boxlang status|use VERSION|matchbox use VERSION|modules list|search|install|update|vscode|links|welcome`. `use` wraps bvm and mvm; modules come from ForgeBox and install with `bx-module`.
- VPN, remote desktop, containers: `bxcachy vpn nordvpn setup`, `bxcachy containers doctor|socket enable|docker-compat`, `bxcachy editor lazyvim|boxlang|status|refresh` (LazyVim with the BxCachy layer and BoxLang syntax).

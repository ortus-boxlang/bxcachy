---
name: bxrig-apps
description: "Use this skill when installing or choosing apps with BxRig: the app catalog and profiles, web apps and the Google, Microsoft and Apple bundles, default browser, terminal and file manager, dictation, Quick Look, databases, cloud storage and the BoxLang developer tools."
---

# BxRig: apps

- The catalog: `bxrig catalog list|show ID|groups|check`. Install: `bxrig install ID... [--yes]`, `bxrig profile-install NAME`, `bxrig install --shell=hyprland|plasma|all`. Sources: pacman, AUR (yay), Omarchy PKGBUILDs, vendor installer scripts, web apps.
- Web apps (frameless windows): `bxrig web add NAME URL --yes`, `web list`, `web rm NAME`, `web install google|microsoft|apple|boxlang|all --yes`.
- Defaults: `bxrig default show|browser ID|terminal ID|filemanager ID --yes`.
- Dictation: `bxrig dictation setup superwhisper|voxtype --yes`. Quick Look: `bxrig quicklook PATH`. Dolphin: `bxrig dolphin doctor [--fix]`. Strata Send-to providers: `bxrig strata integrations`.
- Databases (Podman first): `bxrig db list|start ENGINE|stop|status|logs|remove|info`. Cloud storage as folders: `bxrig cloud remotes|configure|mount NAME|unmount NAME|status`.
- BoxLang tools: `bxrig boxlang status|use VERSION|matchbox use VERSION|modules list|search|install|update|vscode|links|welcome`. `use` wraps bvm and mvm; modules come from ForgeBox and install with `bx-module`.
- Virtual machines: `bxrig vm doctor|list|status|size|info|versions|create windows|create linux NAME|open|start|stop|logs|remove`. Windows (dockur) and Linux desktops (webtop) in Podman containers, any number, ports on 127.0.0.1, data in `~/.local/share/bxrig/vms/NAME`, password in the keyring; Windows needs KVM and your own license; `create` is a plan until `--yes`.
- VPN, remote desktop, containers: `bxrig vpn nordvpn setup`, `bxrig containers doctor|socket enable|docker-compat`, `bxrig editor lazyvim|boxlang|status|refresh` (LazyVim with the BxRig layer and BoxLang syntax).

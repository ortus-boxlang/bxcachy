# BxCachy v0.8.6 — Application Catalog

Curated **137-entry** desktop, TUI, and web application catalog, informed by Omarchy's current app selection and widely used Arch Linux software. Catalog entries are suggestions, not a claim that every package exists in CachyOS repositories.

## Commands

```bash
./bin/bxcachy app-manager gui
./bin/bxcachy app-manager list
./bin/bxcachy app-manager list --kind desktop
./bin/bxcachy app-manager list --kind tui
./bin/bxcachy app-manager list --kind web
./bin/bxcachy app-manager search --query terminal
./bin/bxcachy app-manager show obs chromium
./bin/bxcachy app-manager install obs             # preview
./bin/bxcachy app-manager install obs --yes       # install
./bin/bxcachy app-manager web-shortcut github     # preview
./bin/bxcachy app-manager web-shortcut github --yes
./bin/bxcachy app-manager launch github
./bin/bxcachy app-manager defaults
```

The graphical menu has an **Application Catalog** section. In the catalog GUI, Rofi's fuzzy search filters within the chosen category. No package installation occurs without confirmation.

**Default policy:** The existing v0.8.5 base installation profile is unchanged. All newly cataloged applications are optional until explicitly selected. Previous optional selections (OBS, Kdenlive, Pinta, Chromium, Obsidian, LibreOffice) remain optional.

**Safety:** Only known catalog package names can be installed. Pacman is checked first; AUR entries require `yay` and are explicitly labeled. Web app launchers are opt-in and saved under `~/.local/share/applications/bxcachy-web-*.desktop` without replacing other launchers. Web apps require an installed supported browser. No desktop environment, existing launcher, Hyprland, Noctalia, or KDE configuration is overwritten.

**Limitations:** Catalog entries have not been checked against a live CachyOS package database; some AUR package names may change. Desktop/TUI app launch actions are not yet implemented (install and web launch are). Web launcher uses browser app mode on Chromium-family browsers, and a normal new window on Firefox. No online search is performed by the app manager.

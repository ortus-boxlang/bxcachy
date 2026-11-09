# BxCachy v0.8.4 — Base desktop apps and system utilities

New default base actions: LocalSend, MPV, pacseek package-management TUI (when available in configured pacman repositories), snapshot tooling integration, and an explicit pacman update workflow. Existing LazyVim, clipboard, screenshot, screen recording, Java 21, BVM, MVM, Podman, and Docker aliases remain base.

Optional apps: OBS Studio (`obs`), Kdenlive, Pinta, Chromium, Obsidian, LibreOffice. These are **not** installed by `base install`.

Commands:

```
./bin/bxcachy base plan
./bin/bxcachy base install --yes
./bin/bxcachy apps optional-list
./bin/bxcachy apps optional-install obs kdenlive --yes
./bin/bxcachy system snapshot-status
./bin/bxcachy system snapshot-create  # preview
./bin/bxcachy system snapshot-create --yes
./bin/bxcachy system update-plan
./bin/bxcachy system update --yes
```

Snapshot creation requires a working, preconfigured Snapper or Timeshift installation. Installing Snapper does **not** configure subvolumes or snapshot schedules. Updates do not silently create snapshots. `pacseek` may be unavailable in the configured repositories; it is reported and skipped rather than blocking the remaining base apps. Obsidian may likewise need manual AUR installation. Existing CachyOS, KDE, Hyprland, Noctalia, and configuration files are not replaced.

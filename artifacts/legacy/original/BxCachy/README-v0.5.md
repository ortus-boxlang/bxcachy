# CachyOS Omarchy Pack v0.5 — Native Menu + Shortcuts

## Install

```bash
./bin/desktop-install --install-deps  # installs rofi-wayland + ghostty using pacman
./bin/shortcuts generate            # generates a separate Hyprland include, not activated
./bin/omarchy-gui                   # opens graphical menu under Wayland
```

The graphical menu also appears as a desktop entry in KDE and Hyprland application launchers. The existing terminal menu remains available.

## Where to configure shortcuts

**Graphical:** Omarchy Menu → Settings → Keyboard Shortcuts. Select an action, then enter `SUPER+ALT+M` style binding. The menu validates duplicate combinations and regenerates the managed include.

**CLI:** `./bin/shortcuts list`, `./bin/shortcuts set menu SUPER+ALT M`, `./bin/shortcuts edit`, `./bin/shortcuts reset`, `./bin/shortcuts validate`, `./bin/shortcuts generate`.

**Editable source:** `~/.config/cachyos-omarchy-pack/shortcuts.json` (created on first edit). Generated Hyprland include: `~/.config/hypr/cachyos-omarchy-keys.conf`.

To **activate** on traditional Hyprland configurations, review existing bindings for conflicts and add `source = ~/.config/hypr/cachyos-omarchy-keys.conf` to `~/.config/hypr/hyprland.conf`. Do not blindly activate this in CachyOS's Lua-based Hyprland configuration; integrate it using that session's supported configuration method. No KDE shortcuts are modified. Note that Hyprland can have collisions with bindings in other included config files; validation only detects duplicates within the pack.

The menu is a Rofi-based graphical category picker, **not** a pixel-perfect recreation of the official Omarchy menu or Noctalia UI. Theme synchronization and complete Noctalia panel integration remain separate work. A real CachyOS/Wayland session is required for GUI verification.

## Custom menu

Use `~/.config/cachyos-omarchy-pack/menu.json` as described in README.md. Menu commands execute directly without a shell, with no implicit shell interpolation. Settings is a built-in category.

## Safety

No modifications to KDE, SDDM, bootloader, or kernel. `desktop-install` creates a desktop entry and optionally installs two packages with pacman. `shortcuts` refuses to overwrite an unmanaged generated target. Existing v0.4 `provision` rollback covers only files it stages, **not** the new v0.5 generated shortcut file or desktop entry. Back up custom files before editing. Shortcut updates are not transactional across an existing Hyprland session.

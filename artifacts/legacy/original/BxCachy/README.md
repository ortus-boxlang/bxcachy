# CachyOS Omarchy-inspired Pack (prototype 0.1)

A **selective compatibility pack**, not the complete Omarchy distribution. Targets Omarchy 4.5 application workflows and current Noctalia (`noctalia msg`). Preserves KDE, SDDM, bootloader, kernel, and existing Hyprland configuration.

## Prerequisites
CachyOS with pacman; Hyprland and Noctalia installed and working. Run from your normal user account. Confirm `noctalia msg --help` works in Hyprland. Do not run the pack as root.

## Usage
```bash
./bin/install --list
./bin/install --dry-run
./bin/install --install core
./bin/install --install core,desktop,media
./bin/install --shortcuts-conf
```
The installer checks repository availability and skips unavailable packages; it never enables AUR or adds third-party repositories. Package installation is an explicit sudo/pacman operation.

## Keyboard shortcuts
### Traditional `hyprland.conf`
`./bin/install --shortcuts-conf` copies a standalone keybinding file; it does **not** edit your active config. Review conflicts, then add this line to `~/.config/hypr/hyprland.conf`:
```
source = ~/.config/hypr/omarchy-keys.conf
```
Reload with `hyprctl reload`. This uses Omarchy-inspired shortcuts, **not an exact clone** of every Omarchy binding.

### CachyOS Lua `hyprland.lua`
Do **not** source the `.conf` file in Lua. Copy selected bindings from `config/omarchy-keys.lua` into your existing Lua configuration after reviewing duplicates. Window and workspace bindings deliberately remain unchanged for compatibility.

## Command menu
Run `./bin/omarchy-menu` in a terminal. It uses `gum` when installed, or Bash `select` as fallback. Optionally bind this script to a Hyprland shortcut using its absolute path. The menu is a starter, not Omarchy's Quickshell interface.

## Appearance
Use Noctalia's built-in settings for wallpaper, top panel, floating dock, and theme. See https://github.com/noctalia-dev/noctalia/blob/main/docs/user/compositor-settings/hyprland.mdx for version-matched appearance settings. Avoid replacing your existing `hl.config` block.

## Scope / limitations
- Does not install proprietary or Omarchy-specific AUR apps automatically.
- Does not automatically install LazyVim, Windows VM, AI agents, web apps, or Omarchy's custom shell.
- Does not modify KDE or the display manager.
- `--remove-shortcuts` removes only an unchanged managed file; manually remove the source line.
- Not tested on the user's hardware; review scripts before execution.

## Version 0.2: Interactive new-machine setup
Launch `./bin/setup-tui` from a normal user account. It uses `gum` if available, otherwise a Bash numbered menu. It provides prerequisite checks, package groups, safe shortcut staging, official theme synchronization, and theme selection. Requires Python 3.11+ for `tomllib`.

### Official Omarchy themes
`./bin/theme-manager sync --ref v4.5.0` downloads **all first-party themes present in the selected upstream Git tag** at setup time, including their color definitions and static wallpapers. Themes are intentionally fetched on the target machine rather than bundled into the ZIP. No executable scripts or downloaded app configs are executed. Use `./bin/theme-manager list` and `./bin/theme-manager apply tokyo-night` (substitute a listed name). Noctalia v5 receives a generated v2 palette and first wallpaper through its IPC. The conversion is approximate: it does not reproduce Omarchy's shell layout, full application theme templates, or Hyprland styling. Community themes from the public registry are not automatically downloaded; that catalog is unbounded and third-party.

### Hyprland shortcuts
`./bin/install --shortcuts-conf` stages `~/.config/hypr/omarchy-keys.conf` without activating it. Review your existing shortcuts and include it only if you use `hyprland.conf`. For CachyOS Lua configs, manually merge the example Lua file. **Never replace your active config with the sample.**

### New machine installation sequence
1. Install CachyOS, KDE (optional), Hyprland, Noctalia and Git using CachyOS's own package tools.
2. Run `./bin/setup-tui` and select the packages you need.
3. Sync the first-party Omarchy themes, then select a theme.
4. Review and activate the optional shortcut bindings in your Hyprland configuration.
5. Log into Hyprland and verify Noctalia and your keyboard shortcuts.

### Boundaries
No automatic display manager, bootloader, kernel, network, or KDE changes. No silent AUR installs. No complete mirror of Omarchy's optional web apps, agents, or third-party themes. Theme downloads need internet and git; first-party themes may change across refs. Review package prompts and backups before modifying an existing workstation.

## Extensible Omarchy-style command menu (v0.3)

This pack adds a separate Omarchy-inspired **Apps / Install / Style / Setup / Developer / System** command menu. It is not a copy of Omarchy's proprietary UI or exact Quickshell interface. It uses the Python standard library and optionally Gum for navigation.

```bash
./bin/omarchy-menu --list
./bin/omarchy-menu --validate
./bin/menu-install
./bin/omarchy-menu
```

`menu-install` creates a desktop entry and a user customization file at `~/.config/cachyos-omarchy-pack/menu.json`. It **does not change any KDE or Hyprland keybindings**. The installer prints an optional binding for `Super+Alt+Space` to avoid conflicts with Noctalia's `Super+Space` launcher.

### Add your own commands

Edit `~/.config/cachyos-omarchy-pack/menu.json`. See `menu/custom.example.json`. Every menu item requires a unique `id`, a `label`, and a `command` array. Use `confirm: true` for potentially disruptive actions. A custom section with an existing section ID extends that section; matching item IDs override defaults. New section IDs create new top-level menu categories. `{ROOT}` in command arguments expands to the installed pack path. Commands run directly without a shell unless you explicitly use `bash -lc`.

```json
{"sections":[{"id":"developer","label":"Developer","items":[{"id":"project","label":"Project terminal","command":["ghostty","--working-directory","/home/YOU/Projects"]}]}]}
```

Test without launching the menu using `./bin/omarchy-menu --validate`, inspect with `--list`, and run a single entry with `--run ITEM_ID`. The menu is portable as long as the pack stays in its installed directory; desktop launchers reference that directory. Re-run `bin/menu-install` if you move it.

**Security:** Treat `menu.json` as executable configuration. Only import menu entries from sources you trust. The pack does not automatically run custom commands on startup.

## Version 0.4: Conservative desktop provisioning

`bin/provision` is a **non-destructive first-stage provisioner** for a new CachyOS workstation. It checks available packages before a Pacman transaction, installs Hyprland/Noctalia essentials on explicit request, stages both traditional and Lua shortcut examples without overwriting existing files, and writes timestamped manifests for staged-file rollback. It deliberately does **not** alter active Hyprland configs, SDDM, KDE, kernel, bootloader, or system services.

```bash
./bin/provision plan      # safe preview; no changes
./bin/provision doctor    # executable checks
./bin/provision install   # explicit pacman installation; inspect prompt
./bin/provision stage     # stage shortcuts only; no activation
./bin/provision rollback ~/.local/state/cachyos-omarchy-pack/backups/TIMESTAMP
./bin/setup-tui           # includes new provisioning actions
```

**Important:** Config rollback restores only staged files and refuses to delete modified files; it does not uninstall Pacman packages. The pack does not yet automate Noctalia startup, full application settings, shortcut conflict resolution, or full workstation restoration. In Hyprland, manually review and enable the appropriate staged shortcuts, and configure Noctalia startup per your installed version. Keep KDE as a selectable SDDM session. Always inspect the proposed Pacman transaction before confirming.

# `bxcachy setup` (plan, 2026-11-09)

Status: **plan, decisions made. Built: `setup plasma`, `setup undo plasma`, `tiling`, `setup hyprland` (packages only), `setup undo hyprland`, `setup status`.** Decided with the owner on 2026-11-09 (answers marked [owner]). Builds on COMMAND-CONTRACT.md (mutation rules, exit codes, `--json`), the config service (backup, drift, restore) and the `Installer` (argument arrays, done/failed/skipped, exit 5/6/7).

## 1. Shape

```
bxcachy setup hyprland [--yes] [--dry-run] [--json]    # Hyprland + Noctalia on CachyOS            [owner]
bxcachy setup plasma   [--yes] [--dry-run] [--json]    # HyprKwin tiling on KDE Plasma             [owner]
bxcachy setup plasma --keys | --undo-keys               # hand Plasma's clashing keys over / back   [owner]
bxcachy setup status [--json]                           # what is installed, enabled, managed
bxcachy setup undo hyprland|plasma [--yes]              # remove what setup added; KDE is never touched
bxcachy tiling on|off|status                            # toggle HyprKwin inside Plasma, no logout  [owner]
bxcachy session show | set hyprland|plasma|ask          # which session the login screen preselects [owner]
```

- Each target runs, re-runs and undoes on its own. A re-run changes nothing when everything is in place.
- No `--yes`: print the plan, exit 2. `--dry-run`: print it, exit 0 (contract section 2). Result shape and exits as `install`: `done` / `failed` / `skipped`, exit 7 partial, 4 precondition, 8 config conflict.
- Never run as root (sudo only for the pacman step shown in the plan). KDE Plasma is never removed or reconfigured except what `--keys` hands over, and that is backed up first.

## 2. `setup plasma` (HyprKwin) [owner]

HyprKwin (`DGBooth/HyprKwin`) is a KWin script with Hyprland-style dwindle, master, monocle, scrolling and stage layouts, Hyprland's default keys, and an optional animations effect. It needs Plasma 6.6 or 6.8 on Wayland.

1. Preflight: Plasma 6.6/6.8, Wayland session, `python-dbus`, `qdbus6`; refuse (exit 4) with the reason otherwise. Warn if Polonium, Krohnkite or Bismuth is enabled (HyprKwin's installer does the same).
2. Fetch the repository **pinned to a full commit** (same rule as PKGBUILDs) into a temp directory, and run its `tools/install.sh` as the normal user. That script backs up every global shortcut (`~/.local/share/hyprkwin/shortcuts-before-hyprkwin.json` plus a copy of `kglobalshortcutsrc`), installs the script and the animations effect into `~/.local/share/kwin/`, enables both.
3. Keys: **off by default** [owner]. `setup plasma --keys` runs `tools/hyprkwin-shortcuts.py apply` after showing `check`; `--undo-keys` restores the backup.
4. The animations effect needs one logout; the result says so.
5. `setup undo plasma` runs HyprKwin's own uninstall, which restores the shortcuts.

`tiling on|off|status` enables or disables the KWin script (kwinrc plugin flag plus a KWin reconfigure over D-Bus) and prints the state; a Plasma shortcut for it is a follow-up.

## 3. `setup hyprland`

1. Preflight: CachyOS or Arch, x86_64, free disk, not root, `sudo` present, KDE detected (kept as is).
2. Packages, from the CachyOS and Arch repos, one `pacman -S --needed` call (plan lists them): `hyprland`, Noctalia (the native `noctalia` package from `extra`; verified 2026-11-10 in a CachyOS-enabled container that `noctalia-shell` + `noctalia-qs` are a different, Quickshell-based variant whose fork conflicts with `quickshell`, and that CachyOS's meta-package depends on `noctalia`), `uwsm`, `hyprlock`, `hypridle`, `xdg-desktop-portal-hyprland`, `hyprpolkitagent`, `qt6ct`, `nwg-look`, fonts, and the terminal/file manager already chosen in the catalog. Individual packages, not the CachyOS meta-package (section 5).
3. Session entry: make sure a Hyprland (uwsm) session exists at the login screen. The default session is not changed by `setup`.
4. Configs, written through the config service (backup, atomic replace, journal, drift states): `~/.config/hypr/hyprland.conf` as a BxCachy-managed file that sources a user-owned `hyprland.local.conf`; Noctalia settings and theme; keybindings (Super-based, macOS-friendly: Super acts as Cmd for copy/paste/quit/tab-switch where the apps allow it).
5. A keybinding that logs out to the login screen so KDE can be picked [owner].
6. Report like `install`: `done` / `failed` / `skipped`.

## 4. `session` [owner]

`session show` prints the current login-screen default. `session set hyprland|plasma|ask` writes `/etc/sddm.conf.d/bxcachy.conf` (`Session=`) with sudo, shown in the plan, backed up, and removed by `session set ask`. SDDM is the login manager CachyOS KDE uses; if another display manager is found, `session set` exits 4 and says so.

## 5. Decisions (owner, 2026-11-09)

1. **Individual packages**, never the CachyOS meta-package `cachyos-hypr-noctalia` (it conflicts with `cachyos-desktop-settings`, which the KDE session may rely on).
2. **Super acts as Cmd**, minimum set: Super+C copy, Super+V paste, Super+Tab app switch. More mappings come later. Design notes to verify on a real Hyprland: Hyprland's `sendshortcut` dispatcher can send Ctrl+C/V to the focused window; terminals need Ctrl+Shift+C/V, so terminal classes get their own binding; Super+Tab cycles windows (or uses Noctalia's switcher).
3. **Logout to the login screen: `Super+Shift+Q`.**
4. **Config templates are embedded in the binary** (like the catalog) and written through the config service.

## 5b. One shortcut set on both desktops (owner, 2026-11-10)

The keyboard shortcuts are the same on KDE Plasma and Hyprland. They are defined once, in an embedded table (`id`, `keys`, `action`, optional `apps`), and `setup` renders that table per target:

| Part | Hyprland | Plasma |
|---|---|---|
| Tiling and workspace keys | Hyprland's own default keys | HyprKwin, which uses the same defaults; its clashing-key hand-over is `--keys` |
| Cmd-style keys: Super+C, Super+V, Super+Tab | xremap (Hyprland build) | xremap (KDE build) |
| Logout to the login screen, Super+Shift+Q | a Hyprland bind | a KDE global shortcut (kwriteconfig6 / kglobalshortcutsrc) |

- **xremap, one shared YAML config** [owner]: Super+C / Super+V send Ctrl+C / Ctrl+V; for terminal apps they send Ctrl+Shift+C / Ctrl+Shift+V (plain Ctrl+C would interrupt the running program). The terminal list is part of the table. xremap comes from the AUR (`xremap-hypr-bin`, `xremap-kde-bin`), so `setup hyprland` installs the first and `setup plasma` the second, each as a user service. Both builds read the same config file, written through the config service.
- It needs access to input devices (the `input` group or a udev rule); the plan shows this and it is undone by `setup undo`.
- To verify on a real machine: that xremap's per-app rules match window classes the same way on both builds, and how Super+Tab should behave (window cycle vs Noctalia switcher on Hyprland, KWin's Walk Through Windows on Plasma).
- Implemented (S6b, part 1): `Shortcuts.bx` holds the table; `bxcachy keys show` lists it and `bxcachy keys render xremap|hyprland|plasma` prints each target's text (pure, writes nothing). Part 2: `keys apply [--yes|--dry-run|--force]` writes `~/.config/xremap/config.yml` and `~/.config/hypr/bxcachy.lua` through the config service (so `config list|diff|restore` cover them) and sets Plasma's Log Out shortcut with kwriteconfig6; `keys check` reports clean/missing/drifted (exit 0/1). Part 3: `setup xremap [--build hypr|kde]` (build detected from the desktop) installs `xremap-hypr-bin` or `xremap-kde-bin` with yay, adds the udev rule for /dev/uinput and the user to the `input` group (both remembered), writes the shortcut files and the systemd user unit, and enables the service; `setup undo xremap` reverses only what it added. Super+Tab is a plain Alt+Tab remap [owner]; on Hyprland the Noctalia window switcher is meant to answer Alt+Tab (to verify how Noctalia exposes it). Hyprland (0.55+, Arch has 0.57) reads `hyprland.lua`; the hyprlang `.conf` is deprecated, so bxcachy targets Lua only [owner]. The module `bxcachy.lua` holds the Noctalia autostart, its panel binds, the Alt+Tab window switcher (`noctalia msg window-switcher hold`), the logout bind (`uwsm stop`, the standard for a uwsm session) and the window and layer rules, all taken from Noctalia's v5 Hyprland docs. bxcachy never edits the user's `hyprland.lua`: `keys check` reports `not-loaded` and `keys apply` prints the `require("bxcachy")` line to add. Unverified until a real Hyprland run: the exact bind string format and that 0.57 loads the module. Original intent: `keys show` prints the table with each target's rendering, and `bxcachy keys check` reports where a target's actual shortcut differs from it (drift).

## 5c. Brand assets and starter configs (owner, 2026-11-10)

- Look: Catppuccin-style dark with BoxLang's green-to-cyan gradient (`#00ff75` to `#00dbff`, from boxlang.svg) as the accent. Super+Q closes a window (Cmd+Q habit), logout stays Super+Shift+Q. Natural scrolling is **off** ("inverse", to confirm).
- Images: `assets/` holds the SVG sources (`build.py`), the rendered files (`render.js`): icon, logo and four wallpapers (box, grid, aurora, minimal). `bootstrap/gen-assets.sh` embeds them in `AssetData.bx`; `bxcachy assets list|install [--yes]` writes them to `~/Pictures/BxCachy` and `~/.local/share/bxcachy`, never overwriting a file the user changed. Written as base64 text and decoded with `base64 -d` because MatchBox's `fileWrite` turns binary into a string (upstream gap).
- Next: the Noctalia starter (`~/.config/noctalia/config.toml` plus a custom palette in `palettes/`) and a starter `hyprland.lua` written only when none exists, both through the config service.

## 6. Tests

- Pure `SetupPlan` class (like `Resolver`/`Installer`): preflight results to steps, tested with script tests and injected facts.
- Native tests with fake `pacman`, `git`, `qdbus6`, `kwriteconfig6`, `sudo`: plan output, `--yes` gating, root refusal, partial failure (exit 7), re-run changes nothing, undo.
- Real Arch container (CI): `setup hyprland` installs the packages and writes the configs (no session is started); `setup plasma` checks its preflight refuses cleanly without Plasma. HyprKwin's own installer needs a running KWin, so it is covered by mocks plus the owner's real KDE run.
- Acceptance on the owner's CachyOS KDE machine (cannot be done from CI or this sandbox).

## 7. Tasks

S1 contract text (this file into COMMAND-CONTRACT.md) · S2 `SetupPlan` + preflight facts · S3 `setup plasma` (HyprKwin, pinned) · S4 `tiling on|off|status` · S5 `setup hyprland` packages · S6 config templates + the shared shortcut table, xremap config and per-target rendering · S7 `session show|set` + logout binding · S8 Arch CI steps · S9 real-machine acceptance.

# `bxcachy setup` (plan, 2026-11-09)

Status: **plan, no code yet.** Decided with the owner on 2026-11-09 (answers marked [owner]). Builds on COMMAND-CONTRACT.md (mutation rules, exit codes, `--json`), the config service (backup, drift, restore) and the `Installer` (argument arrays, done/failed/skipped, exit 5/6/7).

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
2. Packages, from the CachyOS and Arch repos, one `pacman -S --needed` call (plan lists them): `hyprland`, Noctalia (`noctalia` / `noctalia-shell` + `noctalia-qs`), `uwsm`, `hyprlock`, `hypridle`, `xdg-desktop-portal-hyprland`, `hyprpolkitagent`, `qt6ct`, `nwg-look`, fonts, and the terminal/file manager already chosen in the catalog. **Open:** use the CachyOS meta-package `cachyos-hypr-noctalia` or individual packages (section 5).
3. Session entry: make sure a Hyprland (uwsm) session exists at the login screen. The default session is not changed by `setup`.
4. Configs, written through the config service (backup, atomic replace, journal, drift states): `~/.config/hypr/hyprland.conf` as a BxCachy-managed file that sources a user-owned `hyprland.local.conf`; Noctalia settings and theme; keybindings (Super-based, macOS-friendly: Super acts as Cmd for copy/paste/quit/tab-switch where the apps allow it).
5. A keybinding that logs out to the login screen so KDE can be picked [owner].
6. Report like `install`: `done` / `failed` / `skipped`.

## 4. `session` [owner]

`session show` prints the current login-screen default. `session set hyprland|plasma|ask` writes `/etc/sddm.conf.d/bxcachy.conf` (`Session=`) with sudo, shown in the plan, backed up, and removed by `session set ask`. SDDM is the login manager CachyOS KDE uses; if another display manager is found, `session set` exits 4 and says so.

## 5. Open questions

1. `cachyos-hypr-noctalia` conflicts with `cachyos-desktop-settings`. Installing the meta-package could remove a package the KDE session relies on. Proposal: **individual packages**, never the meta-package. Needs the owner's call.
2. Keybinding scheme: how far to go with the macOS mapping (Super as Cmd) in Hyprland and in Plasma. Needs a short list of the shortcuts that matter most.
3. Which login-screen shortcut names the logout binding (proposal: `Super+Shift+Q`).
4. Do Noctalia and Hyprland configs ship as templates inside the binary (like the catalog) or as files in the repo that `setup` copies? Proposal: templates embedded and written through the config service.

## 6. Tests

- Pure `SetupPlan` class (like `Resolver`/`Installer`): preflight results to steps, tested with script tests and injected facts.
- Native tests with fake `pacman`, `git`, `qdbus6`, `kwriteconfig6`, `sudo`: plan output, `--yes` gating, root refusal, partial failure (exit 7), re-run changes nothing, undo.
- Real Arch container (CI): `setup hyprland` installs the packages and writes the configs (no session is started); `setup plasma` checks its preflight refuses cleanly without Plasma. HyprKwin's own installer needs a running KWin, so it is covered by mocks plus the owner's real KDE run.
- Acceptance on the owner's CachyOS KDE machine (cannot be done from CI or this sandbox).

## 7. Tasks

S1 contract text (this file into COMMAND-CONTRACT.md) · S2 `SetupPlan` + preflight facts · S3 `setup plasma` (HyprKwin, pinned) · S4 `tiling on|off|status` · S5 `setup hyprland` packages · S6 config templates + keybindings through the config service · S7 `session show|set` + logout binding · S8 Arch CI steps · S9 real-machine acceptance.

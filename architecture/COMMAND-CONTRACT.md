---
title: Command contract
order: 1
summary: Developer reference.
---

# BxCachy command contract (A5 draft, v3)

Target (2026-11-09): Hyprland + Noctalia on CachyOS, KDE kept side by side; see plan.md section 19. `setup` is the headline command.

Status: **proposal, no code written.** Note 2026-11-09: the legacy tree in `artifacts/legacy/original/` is the real v0.10.0 source. It is kept as is and never copied, backed up or modified. Decisions here are inputs to M0 hardening (tasks 1.2 to 1.5) and M1 catalog work. Legacy v0.10.0 is a feature reference only (`artifacts/legacy/original/`).

## 1. Grammar

```
bxcachy <group> <verb> [args...] [--yes] [--dry-run] [--json] [--quiet]
```

- Groups mirror the legacy dispatcher so users keep their muscle memory: `setup apps app-manager catalog profile base extras dev web podman ai vector db db-center vm network cloud cloud-center cloud-services files quicklook dictation integrations desktop desktop-keys mac-keys omarchy-base layout themes icons runner menu shortcuts system config first-run doctor setup`.
- Global verbs on every group: `plan` (read-only), `status` (read-only), `doctor` (read-only checks), `help`.
- Mutating verbs: `install`, `apply`, `remove`, `restore`, `enable`, `disable`. All require `--yes`.
- Existing flat commands (`install`, `optional-install`, `profile-install`, `package-status`, `package-source`, ...) stay as aliases until the grouped form ships, then print a deprecation note.
- Unknown flags, duplicate flags, empty arguments and extra positionals are usage errors (exit 2). Nothing runs.
- Note from M0 history: BoxLang `CLIGetArgs()` puts flags in `args.options`, not `args.positionals`. The parser is one shared function, tested once.

## 2. Mutation rules (apply to every mutating verb)

1. No `--yes`: print the exact plan, change nothing, exit 2.
2. `--dry-run` with `--yes`: print the exact plan, change nothing, exit 0.
3. Preflight everything before the first mutation. A preflight failure means zero changes.
4. Never escalate privilege silently. `sudo` is only called for pacman steps shown in the plan.
5. Never run AUR builds as root (exit 4).
6. Every config file touched goes through the config service (backup, atomic replace, journal). No direct writes.
7. Output lists succeeded and failed items separately. No rollback is promised across pacman and yay.
8. External installer scripts (bvm, mvm, `toolchain node`'s nvm, catalog `source: script`) are downloaded to a temp file, their url and sha256 are printed, and they run as the normal user (never root) with no confirmation gate and no flag: the typed `EXECUTE` and `--allow-external-scripts` were removed on 2026-11-10 (owner: running them is the point of the command). Decision 2026-11-09: no checksum pinning for these scripts.
9. Subprocesses are launched with argument arrays, never through a shell string.

## 3. Exit codes

| Code | Meaning | Example |
|---|---|---|
| 0 | Success or no-op | already installed, or `--dry-run` |
| 1 | Check negative | `package-status` says missing |
| 2 | Usage error or missing confirmation | no `--yes`, unknown flag |
| 3 | Timeout, or item unavailable | pacman lookup timed out, package not in any repo |
| 4 | Precondition failed | root with AUR, not Arch, Java missing, not KDE where required |
| 5 | Official (pacman) phase failed | |
| 6 | AUR (yay) phase failed | |
| 7 | Partial success | some items done, some failed; `--json` lists both |
| 8 | Config conflict | drift detected, symlink or special file at target, concurrent run lock |
| 9 | Internal error | bug, unexpected exception |

Codes 0 to 6 match what the native CLI returns today (2, 3, 4, 5, 6 are already used). 1 is already used for check-negative. 7 to 9 are new. Codes are frozen once published and covered by a contract snapshot test.

## 4. `--json`

One JSON object on stdout, nothing else on stdout. Human text goes to stderr.

```json
{
  "schema": 1,
  "command": "profile install",
  "version": "0.11.0-dev",
  "ok": false,
  "exit": 7,
  "dry_run": false,
  "plan":    [{"id": "jq", "source": "pacman", "action": "install"}],
  "done":    [{"id": "jq", "source": "pacman"}],
  "failed":  [{"id": "x", "source": "aur", "reason": "yay exited 1"}],
  "skipped": [{"id": "git", "reason": "already installed"}],
  "warnings": []
}
```

Read-only commands use the same envelope with a `data` field.

## 5. Catalog (single source of truth)

Decision already made: import legacy `catalog/apps.json` (482 entries) as canonical, keeping its 61 default flags. It replaces the hardcoded lists in `src/bxcachy.bxs` and `scripts/package-manager.sh`.

Entry schema (legacy fields kept, new fields marked):

| Field | Notes |
|---|---|
| `id`, `name`, `kind` (`desktop` `tui` `web`), `category`, `description` | as legacy |
| `source` (`pacman` `aur` `pkgbuild` `script` `manual` `web`), `target` | package name, or URL for web and script |
| `pkgbuild` source: `repo`, `path`, `ref` | Build with `makepkg` as the normal user from a PKGBUILD in a public git repo, pinned to a full 40-character commit (`catalog check` rejects anything else), then install the result with pacman. Used for Omarchy 4.5 apps (`omacom/omarchy-pkgs`). The PKGBUILD is shown before it is built. |
| `check` (for `script`) | argv array that exits 0 when installed, for example `["command","-v","pi"]` |
| `default` | base tier flag |
| `source_status`, `source_confirmed` | legacy provenance flags, kept |
| `profiles` (new) | list of profile ids |
| `deps` (new) | other catalog ids |
| `check` (new) | optional post-install check, argv array |
| `verified_on` (new) | date the target was confirmed against real repos |

Findings from the legacy data (decisions recorded 2026-11-09):

- **Unverified sources.** 176 entries are `source: manual` (95 tui, 81 desktop). Their package names are unverified. Proposal: a CI job that checks every `pacman`/`aur` target against real repos (Arch container, AUR RPC) and fails on unknown names. `manual` entries stay installable only by explicit user action.
- **Default list mismatch.** 61 flagged default (29 pacman, 18 aur, 14 web). `app-profile.json` `base` lists 46. 20 defaults are not in that base list (for example `ark dolphin dolphin-plugins kio-extras rclone fuse3 sshfs nfs-utils cifs-utils podman-desktop tabby beekeeper-studio google-docs google-sheets google-slides kompare filelight ffmpegthumbs kdegraphics-thumbnailers kimageformats`). 5 base entries are not flagged default (`dbeaver filezilla krdc podman-tui rustdesk`). The 61 flags win. The 5 dropped base entries are `dbeaver` (pacman), `filezilla` (pacman), `krdc` (pacman), `rustdesk` (aur) and `podman-tui` (manual). Pending: keep them as curated (not default), or re-flag any as default.
- **Browsers.** `brave` is `aur` (`brave-bin`) and default. A fresh default install therefore needs yay on day one. Decision: bootstrap installs yay only if it is not already present.
- **Preserve list.** Legacy `preserve` (CachyOS, KDE Plasma, Hyprland, Noctalia, existing user configs) becomes enforced rules, not just text.

Named profiles keep the existing four (`core jvm containers terminal`) and are expressed as catalog `profiles` tags. Later profiles (`web backend ai ops desktop full`) are added only after package names are verified.

Ship vs embed (pending confirmation): the default catalog is embedded in the binary at build time, so there is one file to ship and it always matches the code. An optional `~/.config/bxcachy/catalog.json` adds entries or sets `default`/`profiles` on existing ids. It is validated against the same schema and can never delete or replace an embedded entry's `target`, so a bad override cannot redirect an install.

## 6. State and config layout

```
~/.config/bxcachy/            same root as legacy
  bxcachy.json                global settings
  catalog.json                optional user additions (merge-only)
  ai.json menu.json shortcuts.json ...   one file per feature, as legacy
~/.local/state/bxcachy/
  journal/                    one record per apply: files, hashes, backup paths
  backups/                    backups, indexed by the journal
  lock                        single-writer lock
```

`config list|diff|apply|restore` work from the journal, so restore needs only an id. Retention default: keep the last 20 per file. Open: this applies to the user's config files that BxCachy writes, not to the legacy source tree.

## 7. Test contract

- A snapshot test freezes `bxcachy help`, the exit-code table and the `--json` schema.
- Every mutating verb needs these cases: success, no-op, invalid input, dependency failure, privilege rejection, partial failure, recovery.
- Real-system cases run in `tests/arch/` (non-root, real pacman). Cases needing KDE, Wayland or hardware are marked `manual` and tracked in the acceptance log.

## 8. Catalog check, validation and reporting

`bxcachy catalog check [--json] [--online]` plus a CI job that runs it in the Arch container.

**Offline validation (always, no network):** schema version; unique ids; enums for `kind`/`source`; `web` targets are https with no credentials or control characters; package targets match `^[a-zA-Z0-9@._+-]+$`; `default` entries have a non-`manual` source; `profiles` and `deps` reference existing ids; no dependency cycles.

**Online verification (`--online`, CI):** every `pacman` target must resolve with `pacman -Si` (or `-Sg` for groups); every `aur` target must resolve through the AUR RPC (`/rpc/v5/info`); `manual` targets are probed against both and reported as promotable. Results are stored per entry as `verified_on` and a status: `ok`, `moved` (listed source is wrong but another source has it), `missing`, `unverified`.

**Reporting:** a table by status and source for the console, `--json` for tools, and a markdown report in the CI step summary and artifact. Policy: `missing` entries with `default: true` fail CI; `missing` non-default entries are warnings listed in the report; `moved` entries are warnings with the suggested fix.

**First measurement (2026-11-09, stock Arch core/extra only, so CachyOS repos and multilib are not covered):**

| Check | Result |
|---|---|
| `pacman` targets (118) | 111 resolve, 7 do not: 5 exist in AUR (`git-cola insomnia localsend ulauncher wlogout`), 2 found nowhere (`intellij-idea-community-edition`, `swww`) |
| `aur` targets (64) | 40 resolve in AUR, 11 are now official (`doggo impala nwg-dock-hyprland opencode podman-desktop rio spotify-launcher superfile television warehouse zenmap`), 13 found nowhere (`beeper ctop dbgate espanso grokbot herder inshellisense notion-desktop pi-agent tmog todoist upnote zap-whatsapp`) |
| `manual` targets (176) | 93 are official packages today (promotable, for example `jq ripgrep-all tmux kitty starship terraform kubectl`), 83 are not |

The check must also run against the CachyOS repos on a real CachyOS machine before any `missing` entry is removed.

## 9. Open questions

1. The 5 dropped base entries: keep as curated, or re-flag any as default?
2. Catalog embed with merge-only user override: confirmed?
3. Hyprland features (layout, runner, shortcuts, menus) are now in scope, not deferred.

## 10. Implemented so far (2026-11-09)

- `config list|diff|apply|restore|history` (section 6 design; lock is a file created with `fileWriteExclusive`, temp files and journal records are created exclusive with their mode).
- Global flag check and the `--json` envelope (sections 1 and 4) for the read-only commands.
- `catalog list|show|groups|check|version`: the catalog is schema 3 (`catalog/README.md`) and is embedded in the binary by `bootstrap/gen-catalog.sh` (CI fails if `src/bxcachy.bxs` is stale). Filters use the `--name=value` form (`--tier=default --group=infra`), because MatchBox `CLIGetArgs` takes `--name value` as a flag plus a positional. `catalog check` is offline: errors exit 1, warnings (unpinned `pkgbuild` refs, default entries without a package) do not. The user override file is deliberately last (extensibility phase).

## 11. Package commands on the catalog (B2, decided 2026-11-09)

Applies to `plan`, `install-plan`, `install`, `optional-*`, `profile-*`, `package-status`, `package-source`. All read the embedded catalog (schema 3). Hardcoded lists in `Main.bx` go away.

### Selection

```
bxcachy install                       # tier default
bxcachy install ID [ID...]            # exactly these apps
bxcachy install --profile=NAME        # a profile
bxcachy install --optional            # default tier plus optional tier
```

- Naming an app is enough. There is **no `--aur` flag**: anything in the catalog installs from its `source` (`pacman`, `aur`, `pkgbuild`, `web`).
- Unknown id: usage error (exit 2), nothing runs.
- Skip reasons: `optional` (not selected), `wrong_shell` and `unresolved` (catalog has no installable source yet; a named `unresolved` app is reported `failed`, exit 3).
- Already installed apps are `skipped` with reason `installed`.
- Section 2 still applies: no `--yes` prints the plan and exits 2; `--dry-run --yes` prints it and exits 0. AUR and `pkgbuild` builds never run as root (exit 4).
- Profiles live in the catalog (0.3.0): a top-level `profiles` list and, per app, a map profile id to `default`/`optional`. `--profile=NAME` installs the profile's `default` members; `--optional` adds its `optional` ones. See `catalog/README.md`.
- Shells: an app may carry `shells` (`hyprland`, `plasma`). The running shell comes from `XDG_CURRENT_DESKTOP`, overridable with `--shell=hyprland|plasma|all`. Non-matching apps are `skipped: wrong_shell`; a named app still installs.

### Per-source steps

| source | step |
|---|---|
| `pacman` | one `pacman -S --needed` call for all pacman apps (sudo shown in the plan) |
| `aur` | AUR helper (yay) as the normal user, apps one at a time |
| `pkgbuild` | PKGBUILD shown, `makepkg` as the normal user, result installed with pacman |
| `web` | a `.desktop` launcher in `~/.local/share/applications/bxcachy-<id>.desktop` running `brave --app=URL` (written atomically, no package). The resolver adds `brave` to the plan when a web app is selected and brave is not installed. |

### Result shape (`--json`, inside the section 4 envelope)

`data` for `plan`, `install-plan` and `install`:

```json
{
  "selection": { "mode": "default|ids|profile|optional", "ids": [], "profile": null },
  "would_install": [ { "id": "git", "source": "pacman", "targets": ["git"] } ],
  "done":    [ { "id": "git", "source": "pacman" } ],
  "failed":  [ { "id": "docker", "source": "pacman", "error": "target not found" } ],
  "skipped": [ { "id": "jq", "reason": "optional" } ]
}
```

- `plan` and `--dry-run` fill `would_install` and leave `done`/`failed` empty. A real run fills `done`/`failed` and leaves `would_install` empty.
- Exit: 0 all done or nothing to do; 5 pacman phase failed, 6 AUR/pkgbuild phase failed (only when nothing succeeded); 7 some done and some failed.
- `package-status ID` exits 0 when installed, 1 when missing; `data` is `{ "id", "source", "installed": true|false }`.
- `package-source ID` prints `{ "id", "source", "targets", "tier", "group" }`.

Human output is the same lists, one app per line with its source.

### Open questions

1. Decided: a `web` app counts as installed when its launcher file exists.

## 12. Implemented so far, B2 (2026-11-09)

- Catalog 0.3.0: `profiles`, per-profile tier, `shells` (section 11, `catalog/README.md`).
- `Resolver` class (selection) and `Packages` class (read-only commands). `plan`, `install-plan`, `optional-plan`, `profile-plan`, `profile-install-plan`, `package-status`, `package-source`, `profile-list`, `desktop-list`, `tui-list`, `web-list`, `optional-list` run on the catalog. Installed state comes from one `pacman -Qq` call (web apps: launcher file).
- `install`, `optional-install`, `profile-install` run on the catalog through `Installer` (one `pacman -S` call, `yay` per AUR app, pinned PKGBUILDs via `git clone` + `makepkg -si`). Rules as in sections 2 and 11: no `--yes` prints the plan (exit 2), `--dry-run` exits 0, root with AUR or PKGBUILD builds exits 4 before any change, a named app without a source exits 3, partial results exit 7 (5 or 6 when nothing succeeded).
- Web apps install as launchers (see section 11 table). The 28 `pkgbuild` apps are pinned to one commit of `omacom/omarchy-pkgs` and install with `git clone`, `git checkout COMMIT`, `makepkg -si` as the normal user (root exits 4). All of them are optional, so a plain `bxcachy install` skips them.
- Not on the catalog: `apps-doctor`, `dev-plan`.

## 13. Desktop setup (decided with the owner 2026-11-09 and 2026-11-10; all built)

Builds on sections 2 to 4 (mutation rules, exit codes, `--json`), the config service (section 6) and the `Installer` (argument arrays, `done` / `failed` / `skipped`). Hyprland with Noctalia is installed beside KDE Plasma; KDE is never removed or reconfigured except what `--keys` hands over, which is backed up first.

### 13.1 Commands

```
bxcachy setup hyprland [--yes] [--dry-run] [--json]    packages, images, starter configs, shortcut files
bxcachy setup plasma   [--yes] [--dry-run] [--json]    HyprKwin tiling on KDE Plasma
bxcachy setup plasma --keys | --undo-keys              hand Plasma's clashing keys over / back
bxcachy setup hyprland --terminal=ghostty|kitty|alacritty|foot|konsole   Super+Enter terminal (ghostty default)
bxcachy setup hyprland --layout=dwindle|master|scrolling|floating        default window layout in the starter hyprland.lua (dwindle default)
bxcachy setup hyprland --workspaces=N --natural-scroll --layouts=us-intl,es --theme=dark|light|auto --wallpaper=box|grid|aurora|minimal   starter choices (defaults: 2, off, us, dark, box); two or more keyboard layouts switch with Alt+Shift
bxcachy setup terminal [--default=ghostty] [--also=kitty,foot,...]       install terminals, starter configs with the Nerd Font
bxcachy setup shell [--shell=zsh|fish|bash]                              Starship + shell init, login shell (zsh default)
bxcachy setup xremap [--build=hypr|kde] [--yes]        Cmd-style keys: AUR package, input access, user service
bxcachy setup undo hyprland|plasma|xremap [--yes]      remove only what setup added
bxcachy setup status [--json]
bxcachy tiling on|off|status                           HyprKwin inside Plasma, no logout
bxcachy keys show | render xremap|hyprland|plasma | check | apply [--yes] [--dry-run] [--force]
bxcachy assets list | install [--yes] [--dry-run]
bxcachy session show | set hyprland|plasma [--yes] [--dry-run]
bxcachy runner list | show | doctor | launch | select JSON | set P | menu-set P | launcher-command P JSON | menu-command P JSON   the launcher abstraction (13.9)
```

- Every target runs, re-runs and undoes on its own; a re-run changes nothing when everything is in place. No `--yes` prints the plan (exit 2); `--dry-run` exits 0. Results as `install`: `done` / `failed` / `skipped`, exits 0, 2, 4 (precondition: root, wrong OS or CPU, no sudo, no Plasma, unsupported Plasma, X11, nothing to undo, session not installed), 5 (the pacman step failed), 6 (another step failed with nothing done), 7 (a step failed after earlier ones were done; later steps are skipped), 8 (config drift or lock). Never run as root: sudo is used only for the steps shown in the plan. `--json` is always one envelope on stdout (the config service has a quiet mode for that).
- **Exception to `--yes`:** `tiling on|off` acts at once (a reversible user setting meant to sit behind a shortcut). `status` exits 0 on, 1 off, 4 not installed.

### 13.2 `setup plasma` (HyprKwin)

HyprKwin (`DGBooth/HyprKwin`) is a KWin script with Hyprland-style layouts and keys. It needs Plasma 6.6 or 6.8 on Wayland (6.7 warns, older or X11 exit 4). It is fetched **pinned to a full commit** (v1.2.0, `31abb63`, same rule as PKGBUILDs) into a temp directory and installed with its own `tools/install.sh` as the normal user, which backs up every global shortcut first. Plasma's keys stay Plasma's unless `--keys` (runs `tools/hyprkwin-shortcuts.py apply`; `--undo-keys` restores). The animations effect needs one logout. `setup undo plasma` runs HyprKwin's uninstall. `tiling on|off` sets `hyprkwinEnabled` in `kwinrc` `[Plugins]` and asks KWin to reconfigure over D-Bus (`off` also unloads the script).

### 13.3 `setup hyprland`

Preconditions (exit 4): not root, pacman, CachyOS or Arch, x86_64, sudo. Steps, in order:

1. `packages`: the missing ones of 18 official packages in one `sudo pacman -S --needed` call: `hyprland`, native `noctalia`, `uwsm`, `hyprlock`, `hypridle`, `xdg-desktop-portal-hyprland`, `hyprpolkitagent`, `qt6ct`, `nwg-look`, `hyprpicker`, `grim`, `slurp`, `wl-clipboard`, `brightnessctl`, `kitty`, `adw-gtk-theme`, `noto-fonts`, `noto-fonts-emoji`. Individual packages, never the CachyOS meta-package `cachyos-hypr-noctalia` (it conflicts with `cachyos-desktop-settings`, which the KDE session may rely on). Noctalia is the native `noctalia` package; `noctalia-shell` + `noctalia-qs` are a different Quickshell-based variant that conflicts with `quickshell` (a warning, not an error, if installed). The packages added are remembered (`$XDG_STATE/bxcachy/setup-hyprland.json`, mode 600) so `setup undo hyprland` runs `sudo pacman -Rs` on exactly those.
2. `images`: the logo and wallpapers (13.6), missing ones only.
3. `starter`: the Noctalia config and palette, and a first `hyprland.lua` (13.5).
4. `keys`: the shared shortcut files (13.4).

### 13.4 Shortcuts, `keys` and `setup xremap`

One embedded table (`Shortcuts.bx`) holds the shortcuts and is rendered per target. The same keys work on Hyprland and Plasma [owner]:

| Part | Hyprland | Plasma |
|---|---|---|
| Tiling and workspace keys | Hyprland's own keys | HyprKwin (same defaults) |
| Cmd-style keys: Super+C, Super+V, Super+Tab | xremap | xremap |
| Logout to the login screen, Super+Shift+Q | `hl.bind(... "uwsm stop")` | `kglobalshortcutsrc` `[ksmserver] Log Out` via kwriteconfig6 |

- xremap, one shared YAML: Super+C/V send Ctrl+C/V, and Ctrl+Shift+C/V in terminals (a class list in the table); Super+Tab is a plain Alt+Tab remap [owner], answered on Hyprland by Noctalia's window switcher (`noctalia msg window-switcher hold`).
- `keys render` prints a target's text (pure). `keys apply` writes `~/.config/xremap/config.yml`, `~/.config/hypr/bxcachy.lua` and `~/.config/systemd/user/xremap.service` through the config service (backup, journal; `config list|diff|apply|restore` cover them) and sets Plasma's Log Out with kwriteconfig6 when present. `keys check` reports clean / missing / outdated / drifted per piece (exit 0 or 1); a changed file is never overwritten without `--force`.
- Hyprland 0.55+ (Arch has 0.57) reads `hyprland.lua`; hyprlang `.conf` is deprecated, so bxcachy targets **Lua only** [owner]. `bxcachy.lua` holds the Noctalia autostart and panel binds, the Alt+Tab switcher, the logout bind and the window and layer rules, taken from Noctalia's v5 Hyprland docs. bxcachy **never edits the user's `hyprland.lua`**: `keys check` reports `not-loaded` and `keys apply` prints the `require("bxcachy")` line to add (the starter file already has it).
- `setup xremap` installs `xremap-hypr-bin` or `xremap-kde-bin` with `yay` (build from `--build`, else the running desktop), adds the udev rule for `/dev/uinput` and the user to the `input` group (both remembered in `setup-xremap.json`, mode 600), writes the shortcut files and enables the user service; `setup undo xremap` reverses only what it added. It needs one logout.

### 13.5 Look and starter configs

Ortus Brand Book 2025 palette (main `#00FF78`, second `#00DBFF`, accent `#FFF500`, dark `#303446`, which is also Catppuccin Frappé's base) on Frappé neutrals [owner]. `Starter.bx` writes, through the config service and only what is missing (a Noctalia file the user changed is kept; `hyprland.lua` is written only when none exists):

- `~/.config/noctalia/config.toml` and `palettes/BxCachy.json` (`NoctaliaConfig.bx`): dark theme with the custom palette; a top bar with launcher, workspaces and active window on the left; the clock, four world clocks (LAX, NYC, LON, MAD, editable `clock` widgets with a `timezone`) and the media player in the centre; tray, network, bluetooth, volume, battery, notifications and control center on the right; the wallpaper folder.
- `~/.config/hypr/hyprland.lua` from `templates/hyprland.lua` (embedded by `bootstrap/gen-templates.sh`), based on Hyprland's own example: brand-gradient borders, rounded corners, blur, Hyprland's default animations, two persistent workspaces, natural scrolling **off** [owner, "inverse"], Super+Q closes a window (Cmd+Q habit), Super+Return terminal, Super+B browser, Super+E files, Super+F fullscreen, Super+Shift+3/4 screenshots, Super+Ctrl+Q lock, media keys, and `require("bxcachy")`.

### 13.5b Shell and terminal (decided 2026-11-10)

- **Starship is the one prompt for every shell.** `setup shell` installs the shell's packages in one `sudo pacman` call, writes `~/.config/starship.toml` once (the official Catppuccin Powerline preset, Mocha palette, Nerd Font symbols; no question is asked, change it later with `starship preset NAME -o ~/.config/starship.toml`; yours afterwards), and makes the chosen shell the login shell with `sudo chsh`. No Oh My Zsh and no plugin manager: plugins are pacman packages.
- **zsh is the default** (`zsh`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `zsh-completions`), then `fish` and `bash`. All get `starship`, `fzf` and `zoxide`, wired into the shell. zsh and bash load a managed `~/.config/bxcachy/shell.<shell>` from one marked block appended to `~/.zshrc` / `~/.bashrc` (the rest of the file is never touched; the block is added once); fish gets `~/.config/fish/conf.d/bxcachy.fish` (fish loads `conf.d` itself). The managed init is rewritten while unchanged and kept once you edit it.
- **Terminals:** `ghostty` (default), `kitty`, `alacritty`, `foot`, `konsole`. The default is the Super+Enter terminal in the starter `hyprland.lua` and the one `setup hyprland` installs (no longer Kitty); extras install with `setup terminal --also=`. Each terminal with a config file gets a starter written once that sets the Nerd Font (`JetBrainsMono Nerd Font`), so Starship's symbols render in any of them. The xremap terminal list already covers all five.
- Wizard keys: `shell` (default `zsh`), `terminal` (default `ghostty`), `terminals_extra` (default none).

### 13.6 Brand assets

`assets/` holds the sources (`build.py`, composed from the official BoxLang icon in `assets/brand/`, copied unchanged from Ortus-Solutions/ortus-artwork) and the rendered icon, logo and four wallpapers (box, grid, aurora, minimal). `bootstrap/gen-assets.sh` embeds them in `AssetData.bx`; `assets install` writes them to `~/Pictures/BxCachy` and `~/.local/share/bxcachy`, never overwriting a file the user changed. They are written as base64 text and decoded with `base64 -d` because MatchBox's `fileWrite` turns a binary value into a string (upstream gap).

### 13.7 `session`

`session show` lists the installed sessions, the one the login screen preselects, and any automatic login. `session set hyprland|plasma` makes that session the one SDDM preselects by rewriting `Session=` under `[Last]` in `/var/lib/sddm/state.conf` with sudo (a backup `state.conf.bxcachy.bak` is kept; the other lines stay). Hyprland prefers `hyprland-uwsm.desktop`. It never turns on automatic login (a warning if one is set, since it wins). There is no `ask` value: SDDM always remembers the last session. Log out with Super+Shift+Q to see the change.

### 13.9 `runner`: the launcher abstraction (port of the legacy `bxcachy-runner`)

**Design (owner, 2026-11-10): BxCachy is built on an abstraction so runners can be switched.** The rest of BxCachy asks for two things and never names a launcher:

```
Runner.launch()                      open or toggle the launcher
Runner.select( prompt, entries )     show [ { label, icon } ] in a menu, return the chosen position (0 = cancelled)
```

**Super+Space (Hyprland)** is bound once, in the managed `bxcachy.lua`, to `bxcachy runner launch` (falling back to `noctalia msg panel-toggle launcher` when the chosen launcher cannot run), so `runner set` changes what Super+Space opens without ever editing a keybinding. Which launcher answers is a setting, recorded in `~/.config/bxcachy/runner.json` (written atomically); the launcher and the menu provider are chosen separately. **The runner never changes a keybinding or a desktop file** (`doctor` ends with `Shortcut ownership: unchanged`). `set` and `menu-set` are user settings that act at once (no `--yes`), like `tiling`.

Providers are data in `RunnerProviders` (one descriptor each: `id`, `title`, `package`, `launch` argv, and `menu`: dmenu argv with `{prompt}`, `icons`, `returns`). Adding a launcher is adding one descriptor.

| Provider | Launch | Menu (dmenu mode) | Icons | Choice comes back as | Package |
|---|---|---|---|---|---|
| `noctalia` (default on Hyprland) | `noctalia msg panel-toggle launcher` | none | | | with Noctalia |
| `walker` | `walker` | `walker --dmenu` | no | label | Walker |
| `rofi` (default menu) | `rofi -show drun` | `rofi -dmenu -i -show-icons -format i -p` | yes | index | `rofi` |
| `fuzzel` | `fuzzel` | `fuzzel --dmenu --index --prompt` | yes | index | `fuzzel` |
| `wofi` | `wofi --show drun` | `wofi --dmenu --insensitive --prompt` | no | label | `wofi` |
| `vicinae` | `vicinae toggle` | `vicinae dmenu --prompt` | no | label | `vicinae-bin` (AUR) |
| `krunner` | `krunner` | none | | | with KDE |
| `system` | none (the desktop owns it) | none | | | |
| `custom` | your `custom_command` | none | | | |

`select` writes the labels (one per line, newlines inside a label become spaces) to a temporary file and runs the provider's command with it on stdin through `sh -c 'exec "$@" < "$f"'`. Providers that understand Rofi's extended dmenu protocol (`label` NUL `icon` US `name`) get icons; the others get plain labels. A non-zero exit, an empty answer, an unknown label or an index out of range is a cancel, never a wrong choice.

```
bxcachy runner list | show | doctor | launch [--json]
bxcachy runner set P | menu-set P
bxcachy runner launcher-command P JSON_ARGV | menu-command P JSON_ARGV     JSON argument arrays, {prompt} allowed
bxcachy runner select JSON_ENTRIES [--prompt=TEXT] [--json]                prints the 0-based index; exit 1 cancelled, 4 menu cannot run
```

Commands are JSON argument arrays, never shell strings (a string, an empty array or an empty part exits 4). `list` marks the current choice with `*` (`--json` adds each provider's title, package, icon support and answer format). `doctor` shows the commands and whether each executable is on PATH. `launch` starts the launcher detached (exit 4 for `system` or a missing program). The wizard offers Noctalia, Walker, Rofi, Fuzzel and Wofi; Vicinae, KRunner and `custom` work from the command line. `hyprrunner` was dropped (no package found, 2026-11-10). Fuzzel and Wofi flags are from their man pages.

### 13.10 `db`: local databases and search engines as containers (port of the legacy `bxcachy-db` and `bxcachy-vector`)

```
bxcachy db engines | list [--json]
bxcachy db start ENGINE [--name N] [--port P] [--password-file FILE | --ask-password] [--yes] [--dry-run]    create, or start a stopped one; never replaces a container
bxcachy db stop|status|logs ENGINE [--name N]
bxcachy db remove ENGINE [--name N] [--keep-data] --yes              removes the container AND its data (volume and password file); --keep-data keeps the data
bxcachy db info ENGINE [--name N] [--show-password]                  where it listens and how to connect (password masked by default)
bxcachy db engine [podman|docker]                                    which engine runs them (podman by default, saved in ~/.config/bxcachy/db.json)
bxcachy db menu                                                      the control center, on the runner's menu provider (needs a terminal program)
```

Exit codes: 0 done, 2 usage or no `--yes` (the plan is printed; `--dry-run` exits 0), 4 precondition (no container engine, unknown or unsupported engine, bad name or port, `vm.max_map_count` too low), 6 the container command failed. `--json` gives the standard envelope.

**Rules.** Services listen on `127.0.0.1` only. A container that exists is never replaced (a stopped one is started; a running one is left alone). Containers are named `bxcachy-db-<engine>-<name>` (name defaults to `default`; letters, digits and hyphens) and labelled `io.bxcachy.database=true`. Data lives in a **named volume** with the container's name, not a host folder (`db remove` deletes it together with the container and the password files, so the next start is a clean database; `--keep-data` keeps them, and starting the same name again then reuses the volume and its password): rootless containers cannot write to a bind-mounted folder as the image's own user (OpenSearch, Elasticsearch and Meilisearch run as non-root). **Choosing the password:** by default one is generated. `--password-file FILE` uses the first line of a file you made; `--ask-password` asks twice at the terminal without echo (`/dev/tty`, so it needs a terminal; the plan never prompts). A password is **never** a command-line value, so it cannot land in shell history or the process list. It must be 8 to 128 characters with no whitespace (OpenSearch also needs upper and lower case, a digit and a special character). It applies only when the container is created (the image sets it on first start of the data volume): a second start never changes it, an existing container refuses one, and a kept data volume (from `remove --keep-data`) keeps the password it was made with (a different choice is refused). Engines without a password (Redis, Chroma, Qdrant, Weaviate) and Couchbase (set in its web console) refuse the options. The user name is fixed per engine (`postgres`, `root`, `admin`, `elastic`). Generated passwords (24 random bytes as hex) go in `~/.local/share/bxcachy/databases/<container>/` (`password` and `database.env`, mode 600, plus `meta.json` with the port) and reach the container through `--env-file`, never on a command line. Nothing changes system settings: when `vm.max_map_count` is too low `start` stops with the `sudo sysctl -w` line to run. Images are pinned and were checked on Docker Hub on 2026-11-10 (Elasticsearch's from Elastic's docs).

| Engine | Image | Host port | Password | Notes |
|---|---|---|---|---|
| `postgres` | `postgres:17` | 5432 | generated (`postgres`) | |
| `mysql` | `mysql:8.4` | 3306 | generated (`root`) | |
| `mariadb` | `mariadb:11.8` | 3306 | generated (`root`) | |
| `redis` | `redis:7.4` | 6379 | none (localhost only) | `--appendonly yes` |
| `mongodb` | `mongo:8.0` | 27017 | generated (`root`) | |
| `couchbase` | `couchbase:community-8.0.2` | 8091 | **none: set in the web console** | After `db start`, open http://127.0.0.1:8091, choose Setup New Cluster and set the administrator name and password there. Ports 8091-8096, 11210 and 11211 are fixed, so `--port` is refused and only one instance can run. |
| `pgvector` | `pgvector/pgvector:pg17` | 5432 | generated (`postgres`) | run `CREATE EXTENSION vector;` |
| `chroma` | `chromadb/chroma:1.5.9` | 8000 | none | data in `/data` (1.x images) |
| `qdrant` | `qdrant/qdrant:v1.20.0` | 6333 | none | |
| `weaviate` | `semitechnologies/weaviate:1.39.15` | 8080 | none (anonymous access) | local only; never publish the port |
| `meilisearch` | `getmeili/meilisearch:v1.56` | 7700 | generated master key | runs with `MEILI_ENV=production`, which requires the key |
| `opensearch` | `opensearchproject/opensearch:3.9.0` | 9200 | generated (`admin`) | HTTPS, self-signed (use `curl -k`); single node; the password gets a `-Aa1!` suffix to meet OpenSearch's policy; needs `vm.max_map_count` 262144 |
| `elasticsearch` | `docker.elastic.co/elasticsearch/elasticsearch:9.5.6` | 9200 | generated (`elastic`) | HTTPS, self-signed; single node; `-Xms1g -Xmx1g`; needs `vm.max_map_count` 262144 |
| `milvus` | none | | | **not supported**: it needs several services (etcd, object storage); `db start milvus` exits 4 |

**Docker** works through the same commands (`db engine docker`): only `run`, `start`, `stop`, `rm`, `logs`, `ps`, `container inspect` and `volume rm` are used, which both engines share.

**Verified and not.** Tested end to end against a fake Podman/Docker (arguments, files, modes, exit codes, the menu), never against real containers. Not confirmed from the docs fetched: that the Elasticsearch image reads `ELASTIC_PASSWORD` (the page showed a password printed at first start instead) and its data path `/usr/share/elasticsearch/data`; OpenSearch's data path; Couchbase's `/opt/couchbase/var`. A real `db start` of each engine on Podman is part of the acceptance run on a real machine.

### 13.11 `dotfiles`: your own dotfiles repository (decided with the owner 2026-11-11)

```
bxcachy dotfiles plan REPO [--method=chezmoi|yadm|stow|links] [--json]    clones the repo into BxCachy's data folder; changes nothing in your home
bxcachy dotfiles apply REPO [--method=M] [--overwrite] [--yes] [--dry-run] [--json]
bxcachy dotfiles status | undo [--yes] [--dry-run] [--json]
```

`REPO` is a git URL or a local path. **The method is detected** (`--method` overrides): `chezmoi` (`.chezmoiroot`, `.chezmoiignore`, or `dot_` / `.chezmoi*` names), then `yadm` (`.config/yadm/`, or `##` alternate names), then `stow` (`.stowrc`, `.stow-local-ignore`, or only top-level package folders that hold dotfiles), else `links`.

**Your dotfiles win, but nothing is replaced unasked.** The plan splits the repo's files into new, already in place (a link to the repo, or an identical file) and **conflicts** (files you already have that would be replaced; chezmoi templates always count). `apply --yes` needs your approval of the conflicts: `--overwrite`, or a `y` at the prompt (read from `/dev/tty`, so a headless run without `--overwrite` exits 2 and changes nothing). Every replaced file is first moved into `~/.local/state/bxcachy/backups/dotfiles/<time>/`; if a step then fails (exit 6) the originals are put back. `status` shows what was applied; `undo --yes` removes the links BxCachy made (`stow -D` for stow) and restores the originals (for chezmoi and yadm only the originals come back: the files those tools created stay, remove them with the tool).

| Method | Files go to your home by | Applied with |
|---|---|---|
| `links` | one symlink per file (folders are never replaced by a link) | `ln -s` |
| `stow` | each top-level folder is a package | `stow -d CLONE -t HOME -R PACKAGES` |
| `chezmoi` | `dot_`, `private_`, `executable_`, ... prefixes and `.tmpl` are mapped to the plain path for the conflict list | `chezmoi apply --source CLONE --force` |
| `yadm` | `##` alternate suffixes are mapped to the plain name | `yadm clone -f --no-bootstrap REPO` (`yadm pull` when it is already set up) |

Repo-only files (`.git`, `README*`, `LICENSE*`, `.gitignore`, `.stow-local-ignore`...) are never linked. A missing tool (`chezmoi`, `yadm`, `stow`; Arch `extra`) is installed with `sudo pacman -S --needed` as the first step of `apply` (the plan says so). One repository can be set up at a time: a second one is refused (exit 4) until `undo`. Exits: 0 done, 2 no `--yes` or conflicts not approved, 4 precondition (cannot clone, unknown method, nothing to apply, tool not installable), 6 a step failed. The wizard's Import page asks for the repository (empty skips); `init` runs `dotfiles apply REPO` **last**, so your files win over the starter configs, and the conflict question appears at the terminal.

Tested against real git repositories and fake tools (`stow`, `chezmoi`, `yadm`, `pacman`); the real tools have not been run. Private repositories and credentials are git's business (SSH keys or a credential helper must already work).

### 13.12 Apps: Basic or Customize, and your defaults (decided with the owner 2026-11-11)

The wizard's Apps page asks **how you want your apps**: **Basic** (the default: an opinionated, recommended set) or **Customize**.

- **Basic** runs `bxcachy install --shell=hyprland|plasma|all` for the desktop(s) you chose: the catalog's **default tier** (64 apps), desktop-specific ones only for their desktop. Nothing is asked.
- **Customize** shows one extra page per catalog group (11, built from the catalog by `AppPages`, after the Apps page): a multi-choice list per category with the default apps ticked, each option showing its description and the macOS equivalent. Only what is ticked is installed (`bxcachy install ID...`, one command), minus apps that belong to a desktop you did not choose. Categories the wizard asks about itself are not repeated: AI "Coding orchestration", Desktop "Launchers", Terminal "Terminal" and Development "Shell". Answer keys: `apps_<group>_<category>` (a list of app ids). Web apps are one of the groups, like any other.
- **Default browser** (`default_browser`, asked in both modes, default Brave): installed if needed, then set with `bxcachy default browser ID`.
- **Default terminal:** the terminal you picked is set with `bxcachy default terminal ID`.

```
bxcachy default show | browser ID | terminal ID [--yes] [--dry-run] [--json]
```
`browser` runs `xdg-settings set default-web-browser <app>.desktop` (needs `xdg-utils` and the app installed). Desktop entries: firefox `firefox.desktop` and chromium `chromium.desktop` were read from the Arch packages; brave `brave-browser.desktop`, google-chrome `google-chrome.desktop` and edge `microsoft-edge.desktop` are the vendors' usual names (not verified here); other browsers exit 4 (set those in your system settings). `terminal` writes `~/.config/xdg-terminals.list` (the xdg-terminal-exec list; kept if you edited it) with the terminal's desktop entry (ghostty `com.mitchellh.ghostty.desktop`, kitty `kitty.desktop`, alacritty `Alacritty.desktop`, foot `foot.desktop`, konsole `org.kde.konsole.desktop`, all from the Arch packages) and, when `kwriteconfig6` is present, KDE's own setting (`kdeglobals` `[General]` `TerminalApplication` and `TerminalService`; the key names are not verified on a real KDE). Exit codes: 0 done, 2 no `--yes`, 4 precondition (not installed, unknown, no `xdg-settings`), 6 the command failed.

Wizard pages (and questions) may carry `when`; a hidden page is skipped by Next and Back, left out of the sidebar, the step count and the review, and its answers are not in the result.

### 13.8 Tests and what is verified

- Pure `SetupPlan`, `Shortcuts`, `NoctaliaConfig` classes with script tests; native tests with fake `pacman`, `yay`, `git`, `qdbus6`, `kwriteconfig6`, `sudo`, `systemctl` (plan output, `--yes` gating, root refusal, partial failure, re-run, undo, drift, one clean `--json` envelope); the starter TOML and JSON are parsed.
- The real Arch container (`tests/arch/suite.sh`) runs the xremap plan, checks the AUR package names, runs the whole `setup hyprland`, checks the written files, byte-identical wallpapers, `keys check`, and has Hyprland verify the starter config.
- Not verifiable in CI: HyprKwin's installer (needs a running KWin), xremap's per-app rules on both builds, Noctalia accepting every config key, and the exact Hyprland bind strings on a running session. These are covered by the owner's acceptance run on a real CachyOS KDE machine.

### 13.13 Secrets: one way to store and load API keys (decided with the owner 2026-11-11)

`bxcachy secrets` is the single way to keep API keys and tokens. Every machine uses the same commands; `export`/`import` (later) moves them between machines.

| Command | Does |
| --- | --- |
| `secrets status` | backend in use, whether a keyring is available, how many secrets are stored |
| `secrets set NAME [--from-file=F]` | stores a value: typed hidden at the terminal, or read from a file. Never a command-line value. Replaces an existing one |
| `secrets list` | names only, with the coding agent that reads each known key |
| `secrets get NAME [--show]` | says whether it is set and its length; `--show` prints the value |
| `secrets unset NAME --yes` | deletes a value (plan without `--yes`, exit 2) |
| `secrets run [NAMES...] [--strict] -- CMD...` | runs CMD with those secrets in its own environment only; exit code is CMD's. A name that is not set is skipped, `--strict` exits 4 |
| `secrets env [NAMES...]` | prints `export NAME='value'` lines for `eval` (all stored names when none given) |

- Names are environment variable names: capital letters, digits, underscores (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`).
- Backend: the desktop keyring through `secret-tool` (libsecret) when `secret-tool` exists and `org.freedesktop.secrets` is on the user D-Bus (running or activatable); otherwise private files (`~/.local/share/bxcachy/secrets/NAME`, mode 600 in a mode 700 folder). The choice is saved in `~/.config/bxcachy/secrets.json` and shown by `status`. Keyring entries carry the attributes `service=bxcachy name=NAME`.
- Values are passed to `secret-tool` and to programs through standard input and the process environment, never through a command line, a temp file, a log, or `answers.json`.
- `set` is interactive on purpose and needs no `--yes`.
- Exit codes: 0 done, 2 usage or plan without `--yes`, 4 precondition (bad name, secret not set, no value), 6 the store failed.
Loading into shells (default is per command, global is opt-in per key):
- `secrets apply [--yes]` writes `~/.config/bxcachy/secrets.sh` (bash, zsh) and `secrets.fish`. They hold no values: one wrapper per agent command whose key is stored (`claude() { bxcachy secrets run ANTHROPIC_API_KEY -- command claude "$@"; }`). `secrets set` runs it automatically. The shell init templates source these files.
- `secrets global on NAME --yes | off NAME | show`: exports a key to every new shell. `on` prints a warning first (every program, including AI agents and what they run, can read it). The values go to a session cache, `$XDG_RUNTIME_DIR/bxcachy-secrets.env` and `.fish` (mode 600, tmpfs, wiped at logout), never to a config file. The loader files call `secrets unlock` once per login when the cache is missing (the keyring's single unlock prompt); `secrets lock` removes the cache. A globally exported key gets no wrapper.
Moving machines and the keyring:
- `secrets export FILE [--plain] [--force] --yes`: all stored secrets as `export NAME='value'` lines, encrypted with a passphrase by `age -p` (age asks on the terminal; the file is mode 600). `--plain` writes a readable .env instead (mode 600; the plan says so). An existing file is kept unless `--force`.
- `secrets import FILE [--overwrite] --yes`: reads an age file or a .env file; the plan lists each name as new, same or differs. A name that already has a different value is kept unless `--overwrite`. New machine: `install.sh`, `init --answers answers.json`, `secrets import`, `dotfiles apply`.
- `secrets setup [--keyring=kwallet|gnome-keyring|none] [--yes] [--dry-run]`: checks for a Secret Service on the user D-Bus (running or activatable). Installs `libsecret` (`secret-tool`, repo core) and `age` (repo extra) when missing; when no keyring exists, also `kwallet` on Plasma or `gnome-keyring` elsewhere, or the one named. `--keyring=none` installs no keyring and saves the file backend. The plan names what it installs. Package names and `secret-tool` in libsecret were checked on archlinux.org on 2026-11-11.
Secret types and providers (decided with the owner 2026-11-11):
- Every secret has a **type**: `ai` (a key for an AI provider) or `other` (a GitHub token and so on). A name in the provider registry is `ai` automatically; any other name is `other` unless `secrets set NAME --type=ai [--provider=ID]` says otherwise. The type and provider are kept in `secrets.json` (`meta`, names only, never values). `secrets list [--type=ai|other]` filters; `secrets run --type=ai -- CMD` loads every AI key and no other secret.
- The provider registry (`AiProviders`) maps providers to environment variables: anthropic `ANTHROPIC_API_KEY`, openai `OPENAI_API_KEY`, google `GEMINI_API_KEY`, openrouter `OPENROUTER_API_KEY`, novita `NOVITA_API_KEY`, opencode `OPENCODE_API_KEY`, groq, mistral, deepseek, xai, together (`GROQ_API_KEY`, `MISTRAL_API_KEY`, `DEEPSEEK_API_KEY`, `XAI_API_KEY`, `TOGETHER_API_KEY`). Names are from models.dev (the registry OpenCode uses), checked 2026-11-11.
- Each agent declares the providers it accepts (`AiAgents`): Claude Code anthropic, Codex openai, Gemini CLI google, OpenCode all of the above. **An agent is only ever given keys from its own list.** Its wrapper carries the stored ones among them (`opencode() { bxcachy secrets run ANTHROPIC_API_KEY OPENAI_API_KEY -- command opencode "$@"; }`); nothing else is loaded.
- Tests: `tests/secrets-test.sh` (fake `secret-tool` and `busctl`). The registry of agent key names is from the vendors' documentation and the user can store any other valid name.

### 13.14 AI agents (decided with the owner 2026-11-11)

`bxcachy ai` knows four coding agents (`AiAgents`): `claude-code` (command `claude`), `codex-cli` (`codex`), `gemini-cli` (`gemini`), `opencode-cli` (`opencode`), each with the providers whose keys it accepts (see 13.13). Command names were checked in the Arch packages (`openai-codex` ships `/usr/bin/codex`, `gemini-cli` ships `/usr/bin/gemini`; `claude-code` comes from the CachyOS repo). The key names are from the vendors' documentation.

| Command | Does |
| --- | --- |
| `ai list` | each agent: installed, key stored, default |
| `ai default [ID] [--yes]` | shows the default, or sets it (the agent must be installed; plan without `--yes`, exit 2). Saved in `~/.config/bxcachy/ai.json` |
| `ai launch [ID] [--dry-run]` | opens the agent (the default when no ID) in your default terminal as `TERMINAL [-e] bxcachy secrets run KEY -- COMMAND`, detached. The terminal is the first line of `~/.config/xdg-terminals.list` if it names a terminal BxCachy knows and it is installed, else the first installed one. ghostty, alacritty and konsole get `-e`; kitty and foot get the command directly (foot and konsole flags are from memory, not verified here) |
| `ai shell [toggle\|status] [--backend=hyprland\|yakuake] [--dry-run]` | the pull-down AI shell: one shortcut shows and hides a terminal running your default agent (your shell when none is set); it keeps its session while hidden |


**Pull-down AI shell.** The backend follows the desktop: a Hyprland session (`HYPRLAND_INSTANCE_SIGNATURE`) uses a special workspace, KDE Plasma uses Yakuake; `--backend` overrides. Exit 4 when neither applies, when no terminal can carry a window class, or when Yakuake is missing.
- **Hyprland:** the first call starts a terminal with the window class `com.bxcachy.ai` (ghostty `--class=`, kitty and alacritty `--class`, foot `--app-id`; konsole cannot) running `bxcachy secrets run KEYS -- AGENT`, then sizes it to 100% x 45% and moves it to the top with `hyprctl dispatch resizewindowpixel` / `movewindowpixel` (best effort). The Hyprland module (`keys apply`) holds `hl.window_rule({ name = "bxcachy-ai", match = { class = "^com.bxcachy.ai$" }, workspace = "special:ai", float = true })` and the shortcut `Super+\`` running `bxcachy ai shell`. Later calls toggle the workspace: `hyprctl dispatch togglespecialworkspace ai`, and if that fails the Lua form `hl.dsp.workspace.toggle_special("ai")`. Window class is the ghostty config option `class` (GTK builds), and it must look like a GTK application id, hence the dotted name.
- **Plasma (Yakuake):** the first call starts Yakuake, waits for its D-Bus name, adds a tab (`org.kde.yakuake.addSession` on `/yakuake/sessions`), types the agent command (`runCommand`) and shows the window (`toggleWindowState` on `/yakuake/window`); later calls only toggle. The tab is remembered in `$XDG_RUNTIME_DIR/bxcachy-ai-shell`. `init` installs `yakuake` (official `extra`) when Plasma and an agent are chosen. The Plasma shortcut is not written by BxCachy: bind `bxcachy ai shell` in System Settings, Shortcuts (Yakuake also has its own open/retract key).
- **Not verified on a real desktop:** the Hyprland window rule and dispatchers in Lua mode, the percentage resize and move, the special-workspace slide direction, and Yakuake's `runCommand` (its changelog mentions a security prompt). They are on the acceptance checklist.
- Tests: `tests/ai-shell-test.sh` (fake `hyprctl`, `dbus-send`, `yakuake` and terminals).

**Agent sessions (tmux).** `ai session start [ID] [--name=N] [--dir=PATH] [--dry-run]` starts a detached tmux session `bxcachy-AGENT[-N]` running the agent (the default when no ID) in PATH (the current folder by default) through `secrets run`, so it keeps working after you close the terminal. A session that already exists is reported, not replaced. `ai session list` shows only `bxcachy-` sessions. `ai session attach NAME` joins one (NAME is the full name or what follows `bxcachy-`; needs a terminal; detach with the tmux prefix then `d`). `ai session stop NAME --yes` ends one (plan without `--yes`, exit 2). Names are letters, digits, `-`, `_` (up to 40). Exit 4: tmux or the agent missing, bad name, no such session; 6: a tmux command failed. `init` installs `tmux` when an agent is chosen. Tests: `tests/ai-session-test.sh`.

**Local models (Ollama).** `ai models list` and `ai models ps` run `ollama list` and `ollama ps`; `ai models pull NAME` downloads a model with Ollama's own progress (the service must be running); `ai models rm NAME --yes` deletes one; `ai models status` says whether Ollama is installed and its service active; `ai models enable [--yes] [--dry-run]` runs `sudo systemctl enable --now ollama` (the package ships `ollama.service`, checked in the Arch file list 2026-11-11). Model names are letters, digits and `. _ : / -` and are passed as one argument, never through a shell. Exit 4: Ollama missing or bad name; otherwise Ollama's exit code. Wizard: `ai_ollama_service` (confirm, default yes) and `ai_models` (text, comma separated, empty by default) appear when Ollama is ticked; `init` runs `ai models enable`, then one **optional** `ai models pull` per name, so a failed or skipped download never stops the plan. Model names are not checked against Ollama's library (they change), only for safe characters.

Exit codes: 0 done, 2 usage or plan without `--yes`, 4 precondition (unknown or missing agent, no default, no terminal), 6 failed. Tests: `tests/ai-test.sh`, `tests/init_plan_test.bxs`, `tests/init-test.sh`.

Local models: AUR names were checked on 2026-11-11 (`lmstudio-bin`, `jan-bin`, `koboldcpp`, `gpt4all-chat`); Ollama is in `extra`, with `ollama-cuda` and `ollama-rocm` as add-ons that depend on `ollama`. Open WebUI is left out: its AUR package is flagged out of date. Starting the Ollama service and pulling models is later work.

Init rules for this page: a default agent that was not ticked is installed too; `secrets setup` runs whenever an agent is chosen (it installs a keyring only if none exists); the key steps are **optional**, so one that cannot run (no terminal, you press Enter to skip) is reported as skipped with the command to run later and the plan goes on.

### 13.15 SSH key and Plasma keyboard layouts (decided with the owner 2026-11-12)

- `ssh key [--email=ADDRESS] [--yes] [--dry-run]` creates `~/.ssh/id_ed25519` with `ssh-keygen -t ed25519 [-C ADDRESS]` (`~/.ssh` is made mode 700). An existing key is **never** replaced: it is reported with its public half and exit 0. ssh-keygen asks for the passphrase itself on the terminal (empty means none), so it needs a terminal; the public key is printed for GitHub. Exit 2 plan without `--yes`, 4 no ssh-keygen, 6 ssh-keygen failed. The wizard's `ssh_key` answer runs it as an **optional** init step with the git email as the comment.
- `setup keyboard --layouts=us-intl,es [--yes] [--dry-run]` writes the layouts of a Plasma session with `kwriteconfig6 --file kxkbrc --group Layout` (`Use=true`, `LayoutList=us,es`, `VariantList=intl,`, `Options=grp:alt_shift_toggle` when there are two or more, else empty). Layout names are the wizard's (`StarterOptions.keyboards`). Plasma reads the file at login. The key names are from KDE's `kxkbrc`; not run on a real Plasma here. Hyprland takes the same answer through `setup hyprland --layouts`. `init` runs it when Plasma is chosen, so `layouts` is no longer pending there. Locale (`LANG`) is a system setting and is not changed. Tests: `tests/ssh-keyboard-test.sh`.

### 13.16 Control center menu (decided with the owner 2026-11-12)

`bxcachy menu` shows the BxCachy control center with the menu provider you chose (`runner menu-set`). `menu items [--json]` prints the same tree as data.
- **AI:** open the default agent and the pull-down AI shell (both start detached, no window); agent session start and list, local models list and running, API keys list (these open in a terminal window and wait for Enter).
- **Databases:** opens the existing `db menu`.
- **Web apps** (Omarchy's "create web app"): *Create web app* asks for a name and a URL typed into the menu, then runs `web add NAME URL --yes` and shows the result; *List web apps*; *Remove a web app* (pick, confirm, `web rm NAME --yes`). Typed text is supported by Rofi (`rofi -dmenu -l 0` with empty input prints what you type); for Walker, Fuzzel, Wofi and Vicinae, where typed text is not verified, *Create* opens a terminal that runs `web add` with no arguments, which asks for the name, URL and browser itself (the typing is the consent). `web add` with no arguments does the same on its own. Menu order is now AI, Databases, All apps, Web apps, Settings.
- **Settings:** defaults, shortcuts, launcher check, setup status, dotfiles status (read-only views in a terminal).
- Every entry is started without `--yes`, so nothing is changed by the menu itself; the commands keep their own plan/`--yes` rules. Back and Exit are the last entry of each level; cancelling the provider (empty answer) leaves the menu with exit 0.
- Terminals for `run` entries: the first installed of ghostty, kitty, foot, alacritty, konsole (`-e` for ghostty, alacritty, konsole). Exit 4 when there is no menu program, or no terminal for a `run` entry.
- Hyprland binds it to `Super+Alt+M` in the shortcut table (`Super+Alt+Space` is the all-apps window, 13.22). Tests: `tests/menu-test.sh` (fake Rofi and terminal).

### 13.17 Podman helpers, docker compatibility and the LazyVim starter (decided with the owner 2026-11-12)

- `containers doctor [--json]` reports six checks, each with the command that fixes it: Podman installed, rootless (`podman info --format '{{.Host.Security.Rootless}}'`), subuid and subgid ranges for the user (`/etc`, overridable with `BXCACHY_ETC` for tests), a compose tool (`podman-compose` or `docker-compose`), the user socket (`systemctl --user is-active podman.socket`), and a `docker` command that runs Podman. Exit 0 when all pass, 4 when something needs fixing (or Podman is missing).
- `containers socket enable [--yes]` runs `systemctl --user enable --now podman.socket` and prints `DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock`.
- `containers docker-compat [--yes]` installs `podman-docker` (ships `/usr/bin/docker`) and `podman-compose` with `sudo pacman -S --needed`. Refused with exit 4 while the `docker` package is installed (it conflicts). Real wrapper scripts are not written: the packages are the compatibility layer. The wizard asks `docker_compat` (default yes) when Podman is the engine; `init` runs it after the containers profile.
- `editor lazyvim [--yes]` follows lazyvim.org/installation: installs `neovim git ripgrep fd lazygit` when missing, `git clone https://github.com/LazyVim/starter ~/.config/nvim`, removes its `.git`. An existing `~/.config/nvim` is **never** touched (exit 4 with the `mv` to run). Wizard: `editor_starter` (`none` default, `lazyvim`) on the Developer page.
- Package names checked on archlinux.org 2026-11-12 (all in `extra`). Tests: `tests/containers-test.sh`.

### 13.18 Desktop utilities: clipboard history and screen recording (decided with the owner 2026-11-12)

Packages are catalog entries (all `extra`, checked 2026-11-12): `cliphist`, `wf-recorder`, `pavucontrol`, `wiremix`, `nwg-displays`, `playerctl`. `grim`, `slurp`, `wl-clipboard`, `brightnessctl` and `hyprpicker` already come with `setup hyprland`. The wizard's Extras page asks `desktop_utilities` (Hyprland and Both only; `cliphist` and `wf-recorder` preselected); the answers go into the single `install` step.
- `clipboard pick` lists the history with your menu provider, decodes the chosen entry (`cliphist decode`, entry line on standard input) and copies it with `wl-copy`. Text entries only (binary entries are left out of the menu). `clipboard clear [--yes]` runs `cliphist wipe` (plan without `--yes`); `clipboard status` shows the tools and the entry count. Exit 4 when `cliphist`, `wl-clipboard` or the menu program is missing.
- The Hyprland module (`keys apply`) starts the history at login: `wl-paste --type text --watch cliphist store` and the same for images, and binds `Super+Shift+V` to `clipboard pick`.
- `record [toggle|start|stop|status] [--region] [--dry-run]` (default toggle) runs `wf-recorder -f ~/Videos/bxcachy-YYYYMMDD-HHMMSS.mp4` detached (`BXCACHY_VIDEOS` changes the folder); `--region` adds `-g "$(slurp)"`. Stop sends SIGINT (`pkill -INT -x wf-recorder`) so the file is finished. Hyprland binds `Super+Shift+R` (toggle) and `Super+Alt+Shift+R` (a region). Exit 4 when `wf-recorder` or, for a region, `slurp` is missing. `wf-recorder` has no GPU encoding by default; `gpu-screen-recorder` (already in the catalog) is the faster option and is not wired here.
- Tests: `tests/utilities-test.sh`. The `wl-paste --watch` autostart and the shortcuts are not verified on a real Hyprland session.

### 13.19 Shortcut editor (decided with the owner 2026-11-12)

Bindings are built from their key combo (`Shortcuts.bindLine`), so changing the keys changes the rendered Hyprland line and the Plasma text together.
- `keys set ID KEYS [--yes] [--force]` (for example `keys set ai-shell Super+Alt+A`): one or more modifiers (Super, Shift, Alt, Ctrl) plus a letter, a digit, or a named key (Space, Tab, Return, Escape, `` ` ``, comma, period, slash, minus, equal, arrows, Print, F1-F12). Exit 4 when the binding is unknown or is a Cmd-style remap (those are xremap's), the combo is invalid, another BxCachy binding uses it (never overridable), or a line in your own `~/.config/hypr/*.lua` already binds it (`--force` allows that one). Plan without `--yes` (exit 2). The override is saved in `~/.config/bxcachy/shortcuts.json` through the config service; it takes effect with `keys apply --yes`.
- `keys reset ID [--yes]` removes the override.
- `keys conflicts [--json]` reports combos used twice inside the table and clashes with your own `hl.bind(` lines (best effort: it reads `mainMod` and the quoted names on the line, it is not a Lua parser; `bxcachy.lua` is skipped).
- `keys show` marks changed rows (`custom`). The screen-record region shortcut is its own row (`screen-record-region`). Tests: `tests/keys-editor-test.sh`.

### 13.20 Web apps, NordVPN setup and remote desktop (decided with the owner 2026-11-12)

- `web add NAME URL [--browser=brave|chromium|google-chrome|edge|firefox] [--yes]` writes `~/.local/share/applications/bxcachy-web-NAME.desktop` (`XDG_DATA_HOME` is honored). Chromium-family browsers get `Exec=BROWSER --app=URL` (a window without tabs or address bar); Firefox has no app mode, so it gets `--new-window URL`. The browser is `--browser`, else your default (`xdg-settings get default-web-browser`) when it is one of those and installed, else the first installed. NAME is letters, digits, `-`, `_`; the URL must be http(s) without spaces or quotes. Written through the config service: the same text again is fine, an entry you edited is kept (exit 4). `web list` shows the apps BxCachy made (the URL is stored as `X-BxCachy-Web=`); `web rm NAME [--yes]` deletes one. Plan without `--yes` (exit 2). Browser commands: `chromium`; `brave`, `google-chrome-stable`, `microsoft-edge-stable`, `firefox` are the vendors' usual names, not verified here. No icon is fetched (`Icon=web-browser`).
- `vpn nordvpn setup [--yes]` runs the two steps the `nordvpn-bin` AUR package prints in its install notes (checked 2026-11-12): `sudo systemctl enable --now nordvpnd` and `sudo gpasswd -a $USER nordvpn` (log out and in afterwards), then `nordvpn login` by hand. NordLayer is not covered. The wizard's VPN question offers NordVPN (catalog `nordvpn`); `init` installs it and runs the setup as an **optional** step.
- Remote desktop: the wizard's `remote_desktop` multi-choice (Remmina, RustDesk, Moonlight, Sunshine; nothing preselected) installs catalog apps in the single `install` step. These were already in the catalog; there is no command of their own.
- Tests: `tests/web-vpn-test.sh`.

### 13.21 Runtime controls and cloud storage (decided with the owner 2026-11-12)

- `layout [toggle|float|tile|status] [--dry-run]` (default toggle). **Hyprland:** the windows of the active workspace come from `hyprctl activeworkspace -j` and `hyprctl clients -j`; each one that is not already there gets `hyprctl dispatch setfloating address:ADDR` or `settiled address:ADDR`. `toggle` floats everything when at least one window is tiled, otherwise tiles everything. **Plasma:** HyprKwin is a session-wide switch, so toggle flips `tiling on|off` (float = off, tile = on). Exit 4 without a Hyprland or Plasma session. The dispatchers are the documented legacy ones and are not verified on a Hyprland 0.55+ Lua session; there is no keyboard shortcut yet (bind it with the editor or by hand).
- `keys mac [on|off|status] [--yes]` enables or disables the user service `xremap` that `setup xremap` wrote (`systemctl --user enable|disable --now xremap`), so Super+C, Super+V and Super+Tab go back to plain Super shortcuts without uninstalling anything. Exit 4 when the unit is not set up.
- **Not done:** a theme manager (Omarchy themes to Noctalia palettes). It needs Noctalia's runtime theme interface, which has not been verified; `setup hyprland --theme=dark|light|auto` still picks the theme of the starter.
- `cloud remotes | configure | mount NAME [--path=DIR] [--yes] | unmount NAME [--yes] | status`: rclone remotes as folders. `configure` hands your terminal to `rclone config` (BxCachy never sees the logins). `mount` writes `~/.config/systemd/user/bxcachy-cloud-NAME.service` through the config service (`Type=notify`, `rclone mount NAME: DIR --vfs-cache-mode writes`, `ExecStop=fusermount3 -u DIR`, `WantedBy=default.target`), reloads systemd and runs `enable --now`; DIR is `~/Cloud/NAME`, absolute, without spaces or quotes. An edited unit is never overwritten (exit 4). `unmount` disables and stops it and deletes the unit only while it is still the text BxCachy wrote. Exit 4: rclone or fuse3 missing, unknown remote. The wizard's `cloud_storage` (default no) installs `rclone` and `fuse3`. Package facts checked on archlinux.org 2026-11-12. Not run against a real remote here. Tests: `tests/runtime-cloud-test.sh`.

### 13.22 All apps window, answers to take to another machine, snapshot GUIs (decided with the owner 2026-11-12)

- `apps` shows every installed application in one window with your menu provider and starts the choice; `apps list [--json]` prints them. This is Omarchy 4.5's app grid, which opens on `Super+Alt+Space` (source: the Omarchy 4.5 release write-up on starryhope.com: type to filter, arrows to move, Esc closes). The list is the `*.desktop` entries of `/usr/share/applications`, `~/.local/share/applications` and the Flatpak exports (`BXCACHY_APPS_DIRS` overrides, colon separated). A later folder wins for the same file name, so `Hidden=true` in your own folder removes an app. Only `Type=Application` entries without `NoDisplay` or `Hidden` are listed, sorted by name; icons are passed to providers that take them. An entry starts with its `Exec` line, field codes (`%U` and the like) removed, detached. Exit 4 when no menu program or no application is found. There is no press-again-to-close: Esc cancels. Omarchy's dock is not part of this.
- **Shortcut change:** `Super+Alt+Space` is now `all-apps`. The control center moved to `Super+Alt+M` (change either with `keys set`). `menu` has an "All apps" entry. Plasma has its own menu on the Meta key, so nothing is added there. Tests: `tests/apps-test.sh`.
- The wizard's answers live in `~/.config/bxcachy/answers.json` (mode 600, no secrets) and fill the wizard on the next run. `init --export=FILE [--force]` copies them (mode 600); on another machine `init --from=FILE` fills the wizard with them, and `init --answers=FILE --yes` runs them without asking.
- Catalog: `btrfs-assistant` and `timeshift` (both `extra`, verified 2026-11-12) are in the default tier, so a plain `install` and Basic mode install them. **Btrfs Assistant is in the default set only when `/` is Btrfs**: the catalog entry has `filesystems: ["btrfs"]`, the resolver skips it elsewhere as `wrong_filesystem` (an unreadable filesystem counts as not Btrfs; `BXCACHY_ROOT_FS` overrides the detection, which is `findmnt -n -o FSTYPE /`), and naming it (`install btrfs-assistant`) still installs it. Timeshift has no such condition (it also works with rsync). Omarchy's base package list has none of restic, borg, snapper, snap-pac, timeshift or btrfs-assistant (checked in `install/omarchy-base.packages`, 2026-11-12).

### 13.23 Layouts per desktop (decided with the owner 2026-11-12)

The wizard asks the window layout once per desktop you set up: Hyprland (`layout`: dwindle, master, scrolling, floating) and KDE Plasma (`plasma_layout`: dwindle, master, monocle, scrolling, stage). "Both" asks twice. The Plasma list is HyprKwin's (README, 2026-11-12); floating is a per-window rule there, not a layout.
- `tiling layout [NAME]` runs `hyprkwinctl layout [NAME]` for the **current workspace** (HyprKwin remembers each workspace's layout in `~/.config/hyprkwinrc`); without a name it shows the current one. Exit 4 for an unknown layout, no HyprKwin, no `hyprkwinctl`, or no running KWin; 6 when `hyprkwinctl` fails. `init` runs it as an **optional** step (it needs a Plasma session).
- BxCachy does not write HyprKwin's default layout for the other workspaces: the settings page names a "Layout" setting (default dwindle) but its config key is not documented. Set it in System Settings, Window Management, KWin Scripts, HyprKwin. Workspace rules (`workspace = 2, layout:master`) are also entered on that settings page.
- Tests: `tests/tiling-test.sh`, `tests/init_plan_test.bxs`.

### 13.24 System-aware wizard and `status`

`bxcachy status [--json]` (read-only, exit 0) shows what the machine already has in the wizard's terms: detected answers per question (desktops from installed packages, shell from `$SHELL`, default terminal from `xdg-terminals.list`, default browser from `xdg-settings`, AI default, runner, container engine, installed apps per question) and the default apps still missing (the Resolver with the shell and root filesystem). `--json` data: `detected` (id, label, page, value), `installed_catalog_apps`, `default_apps_missing`.

`bxcachy init` on a set-up machine starts from your saved answers merged with that scan (`tune`, the default): lists are joined, single choices follow the system when it says something, installed options show `✓ installed`. `--rerun` uses the saved answers only, `--fresh` the defaults, `--from=FILE` replaces the saved answers with a file (answers exported on another machine). Nothing the machine has is ever removed. The plan output splits `apps` into to install and already installed. `init --from-system --print-answers [--json]` prints the scan merged over the saved answers.

### 13.25 Strata, dictation, Quick Look, Dolphin doctor (decided with the owner 2026-11-12)

- **Catalog source `script`:** `script: { url, args, shell }` runs a vendor installer (`curl -fsSL URL | bash -s -- ARGS`); the URL and arguments are passed as arguments, never interpolated. The URL must be https without credentials, arguments match `[A-Za-z0-9=._/:-]+`, `shell` is `sh` or `bash`. Strata uses it with `--non-interactive`, pinned to a commit of `lgse/strata`.
- **File manager:** the wizard asks `file_manager` (`strata` default, `dolphin`) on both desktops. `flea` is removed. `default filemanager strata|dolphin [--yes] [--dry-run]` runs `xdg-mime default <app>.desktop inode/directory`; `default show` reports it. Strata's installer also sets the folder handler, "Open file location" and the file chooser itself.
- **Send to providers:** `strata integrations [--dry-run] [--json]` puts Strata's LocalSend and KDE Connect providers in `~/.config/strata/providers/<id>/` (`provider.py`, `messages.json`, `LICENSE`, and a `provider.json` naming python3), downloaded from the pinned Strata commit. An existing provider folder is kept. Exit 4 without curl or python3, 6 on a failed download. The `kdeconnect` catalog app installs `kdeconnect`, `sshfs`, `qt6-tools` (its optional dependencies) and `python-gobject` (the provider needs it); `localsend` is already a default app.
- **Rust:** `rust` is a Toolchains option, on by default with Java. `rustup` itself comes with `install.sh`; the plan step is `rustup default stable` (optional).
- **Dictation:** `dictation setup [superwhisper|voxtype] [--yes] [--dry-run]`, `dictation status`, `dictation key [ENGINE]`. Superwhisper is the default (hold Right Alt to talk, release to paste; changed in its own Configuration). Voxtype is the alternative (Omarchy's choice: hold F9; `voxtype setup model`; `~/.config/voxtype/config.toml`) and installs `wtype` too. BxCachy adds no shortcut of its own and does not rebind them. A double tap of Fn or Ctrl is not built: Fn often never reaches Linux and Hyprland cannot bind a double tap. The wizard asks `dictation` (`superwhisper` default, `voxtype`, `none`).
- **Quick Look:** `quicklook [PATH] [--dry-run]` runs `kiview -s PATH` (a folder with no path given: `kiview DIR`). Kiview's README says it has no Dolphin integration yet, so there is no Space key in Dolphin; Dolphin's Preview panel (F11) and Strata's built-in preview exist. `kiview` is an optional AUR app.
- **Dolphin doctor:** `dolphin doctor [--fix] [--json]` checks the applications menu file (an empty "Open with" menu), `XDG_MENU_PREFIX`, the KDE helper packages (`kio-extras`, thumbnailers, `kimageformats`, `ffmpegthumbs`), a default folder handler and a polkit agent. `--fix` runs `kbuildsycoca6 --noincremental`. Exit 0, 4 when something needs fixing, 6 when `--fix` failed. Unverified on a real machine: that these are the only causes.
- Tests: `tests/strata-test.sh`, `tests/extras-test.sh`, `tests/default-test.sh`, `installer_test.bxs` (script source), `catalog_check.bxs`, `init_plan_test.bxs`.

### 13.26 Cheat sheet, screenshots, notifications (decided with the owner 2026-11-12)

- **Noctalia has its own commands** (Noctalia docs, v5.4, `noctalia msg ...`): `screenshot-region|fullscreen|window|annotate` (with built-in annotation), `notification-dnd-set on|off`, `notification-dnd-toggle`, `notification-dnd-status`, `notification-clear-active`, `notification-clear-history`, plus clipboard, wallpaper (`wallpaper-set`) and theme (`theme-mode-set`, `color-scheme-set`, `templates-apply`) commands. BxCachy wraps them; this also removes the Noctalia theme blocker for the theme manager.
- **`keys sheet [--json]`:** the shortcut cheat sheet (Hyprland `Super+K`, like Omarchy), every row of the shared table with its action and how it is bound, in your menu program (searchable); without one it prints the list. Read-only.
- **`screenshot screen|region|window [--edit] [--dry-run]`:** Hyprland with Noctalia: `noctalia msg screenshot-fullscreen|region|window` (`--edit` adds `--annotate`); Hyprland without Noctalia: grim and slurp into the clipboard; Plasma: Spectacle (`-f`, `-r`, `-a`). The desktop is read from `XDG_CURRENT_DESKTOP` (`BXCACHY_DESKTOP` overrides). `screenshot ocr` drags a region and copies its text (tesseract); `screenshot qr` reads a QR code from a region (zbarimg) and copies it; `screenshot menu` is the Cmd+Shift+5 style picker (Screen, Region, Window, OCR, QR, Record). `qr TEXT [--out=FILE.png]` makes a QR code (qrencode). Exit 0, 4 tool missing, 6 failed.
- **Mac shortcuts (Hyprland):** `Super+Shift+3` screen, `Super+Shift+4` region, `Super+Shift+5` menu (the starter no longer binds the first two itself). On Plasma Spectacle's own shortcuts apply; BxCachy does not rebind them (the `kglobalshortcutsrc` keys are not verified). Flameshot is now optional; Spectacle (Plasma only), grim, slurp, tesseract, zbar and qrencode are catalog apps; VLC is optional.
- **`notify dnd on|off|toggle|status`, `notify snooze [30m|2h|90s|MINUTES|off]`, `notify clear [--history]`:** Do Not Disturb through Noctalia. Snooze turns Do Not Disturb on and starts a transient user timer (`systemd-run --user --unit=bxcachy-snooze --on-active=Ns noctalia msg notification-dnd-set off`); `snooze off` stops the timer and turns it off; the default is 30 minutes. Noctalia has no command that opens its history panel, so there is none here. Shortcut `Super+Alt+N` toggles Do Not Disturb; the menu has a Notifications submenu and a Screenshot entry. Exit 0, 4 no noctalia or systemd-run or a bad duration, 6 failed.
- Tests: `tests/capture-notify-test.sh` (fake tools), `shortcuts_test.bxs` (15 rows), `menu-test.sh`, `keys-test.sh`.

### 13.27 Four workspaces and the Plasma panel layout (decided with the owner 2026-11-12)

- **Four workspaces by default:** the wizard's "Workspaces always shown" and the Hyprland starter default to 4 (was 2). On Plasma the same number is the virtual desktop count: `plasma desktops N [--yes]` writes `kwinrc [Desktops] Number=N, Rows=1` and asks KWin to reconfigure.
- **`plasma panels apply|undo|status [--agenda] [--without-weather] [--desktops=N] [--preset=NAME] [--yes] [--dry-run] [--json]`:** replaces your Plasma panels with the BxCachy layout through Plasma's scripting (`qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript`). Top panel, status only, left to right: Application Launcher (`org.kde.plasma.kickoff`), Virtual Desktop Pager (`org.kde.plasma.pager`), Active Window Title (`org.kde.windowtitle`), flexible spacer, Digital Clock (`org.kde.plasma.digitalclock`; with `--agenda` Event Calendar `org.kde.plasma.eventcalendar`), flexible spacer, Weather Report (`org.kde.plasma.weather`, off with `--without-weather`), Media Controller (`org.kde.plasma.mediacontroller`), KVitals (`org.kde.plasma.kvitals`), System Tray (`org.kde.plasma.systemtray`, notifications are inside it) and Panel Colorizer (`luisbocanegra.panel.colorizer`). Panel Colorizer's islands are switched on (`islandsEnabled`, `islandSeparatorWidget`) and its islands separator sits between Launcher + Pager, Window, Clock, Media + KVitals and Tray; the built-in preset (default Rounded Widgets) is applied with the Colorizer D-Bus signal `luisbocanegra.panel.colorizer.all.preset`. Bottom panel: a dock with the icons-only Task Manager (`org.kde.plasma.icontasks`). Plugin ids come from each widget's `metadata.json`.
- **Backup and undo:** the first `apply` copies `plasma-org.kde.plasma.desktop-appletsrc` to `~/.config/bxcachy/plasma-panels/backup/` and keeps that first copy; `undo --yes` puts it back (log out and in). Without a running Plasma session (for example from Hyprland) the script is saved and a one-time autostart entry applies it at the next Plasma login and is removed once applied. Exit 0, 2 plan without `--yes`, 4 precondition, 6 Plasma refused the script.
- **Wizard (Plasma or Both):** `plasma_panels` (`bxcachy` default, or `keep`), `plasma_weather` (default on), `plasma_agenda` (default off). The plan installs the widget apps (Plasma-only catalog entries `panel-colorizer`, `panel-colorizer-islands`, `window-title`, `kvitals`, `kdeplasma-addons`, `event-calendar`) and runs the optional step `plasma panels apply --desktops=<workspaces>` (or `plasma desktops N` when you keep your panels). `kvitals` is only packaged as a git build.
- **Not verified on a real Plasma session:** the Panel property names (`location`, `height`, `lengthMode`), Panel Colorizer's config group and keys beyond what its `main.xml` declares, and that applying the preset by D-Bus reaches the new instance. The layout is reversible through the backup.
- Tests: `tests/plasma-panels-test.sh` (fake qdbus6, kwriteconfig6, dbus-send), `init_plan_test.bxs`, `wizard_app_test.bxs`.

### 13.28 Web app bundles, databases, BoxLang ecosystem (decided with the owner 2026-11-13)

- **Catalog:** DBeaver (`dbeaver`, extra) and HeidiSQL (`heidisql-qt6-bin`, AUR native Qt6 build; HeidiSQL's download page lists Linux x64 and arm64) are optional; TablePlus was dropped. RClone Browser (`rclone-browser`, AUR) is the optional GUI for S3 and other clouds (the Transmit and Cyberduck role). Apple web apps (iCloud, Mail, Calendar, Notes, Photos, Pages, Numbers, Keynote, Apple Music, Apple TV) and Try BoxLang (default) are web apps. Catalog apps may carry a `bundle` (`google`, `microsoft`, `apple`, `boxlang`).
- **`web install google|microsoft|apple|boxlang|all [--yes] [--dry-run] [--json]`:** adds every web app of the bundle as a launcher entry (the catalog's web source). Exit 0, 2 plan without `--yes`, 4 unknown bundle, 6 an entry failed. The menu has "Install all Google, Microsoft, Apple apps" under Web apps and the wizard asks `web_bundles` (a multi-select).
- **`boxlang status|use VERSION|matchbox use VERSION|modules ...|vscode|links|welcome [--json]`:** on top of what `install.sh` installs (Java 21, `bvm`, `mvm`, BoxLang, MatchBox). `use` runs `bvm install` when the version is missing then `bvm use` (`latest`, `snapshot` or a number); `matchbox use` does the same with `mvm`. `modules list|search TEXT` reads ForgeBox's public API as implemented in saas-forgebox `modules_app/api-v1` (`https://forgebox.io/api/v1/entries/boxlang-modules?orderBy=popular&max=50&offset=N[&searchTerm=]`; `max` is capped at 50 per call, so the pages are followed until one is short, at most 20); `modules install SLUG...|installed|outdated|update` wrap `bx-module`. `vscode` runs `code --install-extension ortus-solutions.vscode-boxlang` and `ortus-solutions.vscode-boxlang-developer-pack` (names from Ortus's docs; VS Code is a default app). `links` lists the BoxLang sites; `welcome` writes `~/.config/bxcachy/welcome.html` (Try BoxLang, MatchBox, the ecosystem links) and opens it. The wizard (Toolchains page) asks `boxlang_modules` and `boxlang_vscode`; the menu has a BoxLang submenu. Exit 0, 4 tool missing or bad name, 6 failed. `boxlang new APP` is deliberately not built (later).
- Tests: `tests/boxlang-test.sh` (fake bvm, mvm, bx-module, code, curl), `web-vpn-test.sh`, `init_plan_test.bxs`, `menu-test.sh`.

### 13.29 Mac-style extras (decided with the owner 2026-11-13)

- **Cmd keys:** the shared shortcut table now remaps `Super+Z X A S F T N O P R W L B I U Comma` to their Ctrl versions in apps (undo, cut, select all, save, find, new tab, new window, open, print, reload, close tab, address bar, bold, italic, underline, preferences). In terminals `Super+T N W F` become `Ctrl+Shift+T N W F` and `Z X A S ...` pass through unchanged so shell shortcuts keep working. `Super+Q` closes the window (starter), `Super+M` minimizes and `Super+Shift+M` shows minimized windows (`window minimize|restore`: `hyprctl dispatch movetoworkspacesilent special:minimized` and `togglespecialworkspace minimized`). `Super+Ctrl+E` emoji picker, `Super+Alt+Escape` force quit, `Super+Ctrl+Up` overview, `Super+Ctrl+X` dictation toggle (`voxtype record toggle`, from the Voxtype README), `Super+Alt+Shift+N` night shift toggle.
- **`emoji`:** `rofimoji` (Omarchy uses Walker's symbols mode on `Super+Ctrl+E`). **`forcequit`:** Hyprland `hyprctl kill` (click the window); Plasma `qdbus6 org.kde.KWin /KWin org.kde.KWin.killWindow`. **`overview [setup]`:** Hyprland `hyprctl dispatch hyprexpo:expo toggle` (`setup` runs `hyprpm update`, `hyprpm add https://github.com/hyprwm/hyprland-plugins`, `hyprpm enable hyprexpo`); Plasma `org.kde.kglobalaccel /component/kwin invokeShortcut Overview`. Hot corners are not built: KWin's `[Effect-overview] BorderActivate` values could not be verified (set them in System Settings > Screen Edges).
- **`nightshift [on|off|toggle|status] [--location=LAT,LON]`:** Hyprland: a user service `bxcachy-wlsunset.service` running `wlsunset -l LAT -L LON -t 3500 -T 6500`; the coordinates come offline from your time zone in `/usr/share/zoneinfo/zone.tab` or `zone1970.tab` (`BXCACHY_ZONEINFO` overrides the folder); an edited unit is kept. Plasma: `kwinrc [NightColor] Active=true, Mode=Automatic` (the Mode value is unverified). The wizard (Input page) asks `night_shift`, default on.
- **`gpu doctor`:** `lspci` vendors (NVIDIA, AMD, Intel) and the driver packages that are missing (`nvidia-utils`, `libva-nvidia-driver`; `mesa`, `vulkan-radeon`, `libva-mesa-driver`; `mesa`, `vulkan-intel`, `intel-media-driver`), with `ollama-cuda` or `ollama-rocm` for local AI. Exit 4 when something is missing. CachyOS normally installs the driver itself.
- **`input doctor` and `input gestures [--yes]`:** Magic Mouse and Trackpad checks (kernel `hid_magicmouse`, the `bluetooth` service, the `input` group) and `~/.config/libinput-gestures.conf` with three-finger swipes (left and right: `hyprctl dispatch workspace e+1` and `e-1`; up: overview; down: previous workspace), then `libinput-gestures-setup autostart` and `start`. The wizard asks `gestures` (Hyprland, default on) and installs `libinput-gestures` and `bluez`.
- **`airplay on|off|status`:** UxPlay as `bxcachy-airplay.service` (`uxplay -n BxCachy`); it needs `avahi-daemon`. Wizard question `airplay`, default off.
- **Keyboard:** the layout `us-mac` (English, Macintosh variant, Option-key characters) is a wizard choice for Hyprland and Plasma.
- **`settings export FILE.tar.gz [--force]` and `settings import FILE.tar.gz [--yes]`:** the BxCachy settings (not secrets, backups or state); import backs up each existing file as `NAME.bak-STAMP` and refuses archives with paths outside `bxcachy/`. The menu has a Cloud storage submenu (remotes, configure, mounted status).
- Not verified on a real machine: hyprexpo with the Lua config era, KWin `killWindow`, kwinrc NightColor, UxPlay, libinput-gestures with a Magic Trackpad.
- Tests: `tests/macextras-test.sh`, `shortcuts_test.bxs`, `menu-test.sh`, `keys-test.sh`.

### 13.30 One-line installer, update channels, updates and notifications (decided with the owner 2026-11-13)

- **One line:** `curl -fsSL https://downloads.ortussolutions.com/ortussolutions/bxcachy/install.sh | bash` (`bootstrap/web-install.sh` is published as `install.sh`). It shows the BxCachy wordmark in the cyan to green gradient, the tagline and "Powered by BoxLang", checks the machine (CachyOS or Arch, not root, x86_64, sudo), downloads the channel's `bxcachy-linux-x86_64` and `bootstrap.tar.gz`, verifies the Ed25519 signature of the release information (`version-latest.properties.sig`, OpenSSL, public key embedded in the published script) and the SHA-256 of both files against it, runs the stages of `bootstrap/install.sh` (`packages`, `toolchains`, `binary --binary`, `core`) behind spinners, then the setup wizard. There is no custom menu: it installs everything the wizard's defaults call for. Log: `~/.cache/bxcachy/install.log`.
- **No human input:** `... | bash -s -- --yes [--answers FILE] [--channel stable|beta] [--no-wizard]`. `--yes` never asks (it needs passwordless sudo or a primed `sudo -v`), the wizard then runs `bxcachy init --answers FILE --yes` or, without a file, `bxcachy init --defaults --yes` (the wizard's default answers). `--dry-run` shows the banner and checks and does nothing. `--base-url` or `BXCACHY_BASE_URL` points elsewhere. Exit 1 on any failure (nothing is installed after a failed checksum), 2 when you decline.
- **Channels and S3 (`downloads.ortussolutions.com/ortussolutions/bxcachy/`):** `stable/` (a `v*` tag), `beta/` (every push to `development`, the bleeding edge), each with `bxcachy-linux-x86_64`, `.sha256`, `bootstrap.tar.gz`, `.sha256` and `version-latest.properties` (`version`, `commit`, `sha256`, `channel`, `builtAt`); `snapshots/<version>-<sha>/` keeps every beta build and `releases/<version>/` every stable one (uploads never delete). CI job 6 publishes when the AWS secrets exist (`AWS_ACCESS_KEY`, `AWS_ACCESS_SECRET`).
- **`update check [--notify]`:** compares the running binary's SHA-256 with the channel's `version-latest.properties`; exit 10 when an update is available, 0 when current, 5 when the server is unreachable; also counts pending system updates (`checkupdates`). `update apply [--yes]` downloads the channel's binary, verifies its SHA-256 against its `.sha256` and the signed release information, and replaces the installed binary atomically (exit 5 on a mismatch or a bad signature, the old binary stays). `update channel [stable|beta]` shows or sets the channel (`~/.config/bxcachy/update.json`; the wizard asks `update_channel`, default stable). `update notifications on|off|status` manages a daily user timer `bxcachy-update-check.timer` that runs `update check --notify` and shows a notification (`noctalia msg notification-show`, else `notify-send`); the wizard asks `update_notifications`, default on. `system update [--yes]` takes a snapshot first when snapper or timeshift is present, then `sudo pacman -Syu --noconfirm` and, with yay, `yay -Sua --noconfirm`. The menu has Settings entries for check, apply, both channels, notifications on and off, and system update.
- **Signing (owner decision 2026-11-13: sign the installer and update):** CI signs every `version-latest.properties` and `install.sh` with Ed25519 (`openssl pkeyutl -sign -rawin`) using the secret `BXCACHY_SIGNING_KEY`; the properties carry `sha256` (binary) and `bootstrap_sha256` (bundle). The public key is `keys/release.pub` (made with `scripts/gen-signing-key.sh`), embedded into the binary (`bootstrap/gen-releasekey.sh` writes `src/bxcachy/ReleaseKey.bx`) and into the published `install.sh` (CI replaces `@@PUBKEY_B64@@`). With a key a missing or invalid signature, or a file that does not match the signed hash, stops the install or update before anything changes (exit 1 for the installer, 5 for `update`); without a key (a development build) only SHA-256 is checked. Limit: the very first `curl | bash` still trusts the script it downloads (TLS and the bucket), so the signature protects the files the script fetches and every later update; verify `install.sh.sig` by hand with `keys/release.pub` for a stricter first install.
- Tests: `tests/web-install-test.sh` (fake server and stages, signed and unsigned), `tests/update-test.sh`, `init_plan_test.bxs`.

### 13.31 Agent skills and the documentation site (decided with the owner 2026-11-13)

- **Skills:** `skills list [--tag=T]|search TEXT|show REF|install [NAME|REF]... [--yes]|installed|update [--yes]|remove NAME [--yes]|status|link`. The store is `~/.agents/skills` (`BXCACHY_SKILLS_DIR`); each skill folder is linked (a symlink, never over something of yours) into the skills folder of every agent present: `~/.claude/skills`, `~/.codex/skills`, `~/.gemini/skills`, `~/.config/opencode/skills` (the last three are best effort). `~/.config/bxcachy/skills.json` records what BxCachy installed (`embedded` or `hub`, the reference, the SHA-256). Names: `bxcachy` (five skills embedded in the binary from `skills/*/SKILL.md` by `bootstrap/gen-skills.sh`: `bxcachy`, `bxcachy-install-update`, `bxcachy-desktop`, `bxcachy-apps`, `bxcachy-ai`), `boxlang` (`ortus-boxlang/skills/boxlang-developer~language-fundamentals`) and `matchbox` (`.../boxlang-developer~runtime-matchbox`). A reference is `OWNER/REPO/SLUG` (SLUG is `CATEGORY~NAME`) or `OWNER/REPO/CATEGORY/NAME`. The hub is `https://skills.boxlang.io` (`BXCACHY_SKILLS_URL`), whose API (sites-skills.boxlang.io, `app/handlers/api/Skills.bx`) is `GET /api/skills?search=&tag=&perPage=&sort=`, `GET /api/skills/:owner/:repo/:slug`, and `POST /api/install {owner,repo,skill}` which returns the SKILL.md with its audit; a skill that failed its audit is refused (403). Exit 0, 2 plan without `--yes`, 4 bad reference or unknown name, 5 the hub did not answer or refused, 6 a write failed. The wizard (AI page) asks `agent_skills` (default `bxcachy`, `boxlang`, `matchbox`; optional) and runs one optional step; the menu has Settings entries.
- **Docs:** built with bxSites (`bxsites.yaml`, `docs/`) and published to GitHub Pages at `https://bxcachy.boxlang.io` by `.github/workflows/docs.yml` (a pull request builds and audits only). `docs/` is the version being written (1.0.x); `bxSites version:new --name=1.0.x` freezes it and `versions.default` then serves it at the root with `docs/` at `/next/`. i18n is configured for English only (`i18n.defaultLocale`). `docs/reference/commands.md` is generated from the usage text in `src/Main.bx` by `bootstrap/gen-docs.sh` (CI checks it). The bxSites agent skills (`ortus-boxlang/bx-sites-skills`) are installed in `.agents/skills` (`skills-lock.json`).
- Tests: `tests/skills-test.sh` (fake hub and agents), `init_plan_test.bxs`.

### 13.32 Themes, the Neovim layer and the Starship BoxLang module (decided with the owner 2026-11-13)

- **Command:** `theme list|show NAME|set NAME [--mode=theme|dark|light|auto] [--keep-wallpaper]|random|next|mode theme|dark|light|auto|install GIT_URL [--name=N] [--force]|import PATH [--name=N] [--force]|remove NAME|status`, all with `--dry-run` where they change anything and `--json`. Like `runner set` these are settings: they act at once (no `--yes`). Exit: 0 done, 2 bad usage or mode, 4 unknown or invalid theme (nothing is written), 6 a file could not be written.
- **Theme format:** an Omarchy theme folder, so themes move both ways: `colors.toml`, optional `neovim.lua`, optional `backgrounds/` (the first file is the wallpaper). Both `colors.toml` shapes are read: the named one of Omarchy 4 master (`accent background foreground selection muted red green yellow blue magenta cyan bright_*`, `mode = "dark"|"light"`) and the older `color0..color15` one. The named shape maps to the 16 ANSI slots as Omarchy's terminal templates do. A missing required key or a value that is not `#rrggbb` rejects the whole theme. Light or dark is the file's `mode`, else the background luminance (above 0.4 is light).
- **Sources, first match wins:** `~/.config/bxcachy/themes/NAME` (installed or imported), `~/.config/omarchy/themes/NAME` and `~/.local/share/omarchy/themes/NAME` (found on disk), then 15 bundled in the binary: 10 from Omarchy (catppuccin, catppuccin-latte, tokyo-night, gruvbox, nord, rose-pine, kanagawa, everforest, matte-black, flexoki-light; MIT, credited in `themes/NOTICE.md`) and 5 of ours (`bxcachy`, `bxcachy-light`, `bxcachy-midnight`, `bxcachy-cyan`, `bxcachy-forest`). `install` takes an https git URL only (a repository named `omarchy-NAME-theme` becomes `NAME`), clones it shallow, validates it, refuses symlinks and an existing theme (without `--force`), and copies it without `.git`. Only your own themes can be removed, never the current one.
- **What `set` writes** (through the config service: atomic, backed up, journalled; unchanged files are skipped): the Noctalia palette `~/.config/noctalia/palettes/BxCachyTheme.json` (the 16 roles are derived from the theme, both variants carry the same colours), `~/.config/bxcachy/theme/{ghostty,kitty.conf,alacritty.toml,foot.ini,hypr.lua}`, `~/.config/btop/themes/bxcachy.theme`, `~/.local/state/bxcachy/current/theme/neovim.lua` and every theme's `neovim.lua` in `~/.config/bxcachy/nvim-themes/`. Then it tells the desktop: `noctalia msg color-scheme-set custom BxCachyTheme`, `theme-mode-set`, `wallpaper-set` (a bundled BxCachy theme brings one of our wallpapers, an on-disk theme its `backgrounds/`, other bundled themes keep yours), `plasma-apply-colorscheme BreezeDark|BreezeLight` on KDE, `hyprctl reload` inside Hyprland. A missing or silent Noctalia is a note, not an error. Mode `theme` (default) follows the theme; `dark`, `light` or `auto` pin it; the mode survives `set`.
- **Where the files are used:** the terminal starters (written once) include `~/.config/bxcachy/theme/...` (ghostty `config-file = ?path`, kitty `include`, alacritty `[general] import`, foot `include=`) and `TerminalConfig.apply` writes the default theme files, so an include never points at nothing; your own terminal configs are never edited. The managed `hypr/bxcachy.lua` reads `theme/hypr.lua` (border colours). btop needs `color_theme = "bxcachy"` in your `btop.conf`, which we do not edit.
- **Not themed in v1:** the Starship prompt (fixed Catppuccin Mocha palette, no include mechanism), VS Code, Chromium, GTK and Qt apps (whether `noctalia msg templates-apply` themes them is unverified).
- **Neovim layer** (`editor lazyvim|boxlang|status|refresh`): after the starter is cloned (an existing `~/.config/nvim` is never touched) the layer is added: `lua/config/bxcachy.lua` (relativenumber off, autoformat off, OSC 52 clipboard over SSH, loaded by one line added to `options.lua`), `lua/plugins/bxcachy.lua` (no news popups, no scroll animation, transparent lualine), `plugin/after/bxcachy-transparency.lua`, `lua/plugins/boxlang.lua` (`ortus-boxlang/vim-boxlang`, loaded at startup so its ftdetect runs first), `lua/plugins/bxcachy-themes.lua` (every theme's colourscheme plugin listed lazily from `nvim-themes/`), `lua/plugins/bxcachy-theme-reload.lua` (a libuv watcher re-applies the colourscheme when the theme file changes), `lua/plugins/theme.lua` (a link to the current theme's `neovim.lua`) and the neo-tree extra merged into `lazyvim.json`. It is modelled on Omarchy's `omarchy-nvim` package, written by us. `editor boxlang` adds only the plugin file to a LazyVim config you have. `refresh` rewrites the files still as BxCachy wrote them and keeps the ones you changed unless `--force`.
- **Wizard:** `theme_name` (default `bxcachy`; a Light answer with the default picks `bxcachy-light`) runs `theme set` after the terminals, optional, for Hyprland and Plasma; the editor answer now includes the layer and BoxLang syntax. The Themes menu has next, random, the five BxCachy themes, the four modes and status.
- **Starship:** the starter prompt shows the BoxLang version like Java: `custom.boxlang` (`${custom.boxlang}` in the format), shown only in a directory with `.bx .bxs .bxm .cfc .cfm .cfs` files or `box.json`, `Application.bx`, `Application.cfc`. It has no `when` (Starship shows a custom module when ANY of `when`, `detect_files`, `detect_extensions` matches, so `when` would show it everywhere); its command prints the `~/.bvm/current` symlink name (honouring `BVM_HOME`) or nothing. The starter is written once, so existing installs see the change with `bxcachy config diff starship`.
- **Verified and not:** tested with fake `noctalia`, `plasma-apply-colorscheme`, `hyprctl`, `git`, `pacman` (`tests/theme-test.sh`, `tests/editor-test.sh`, `tests/theme_colors_test.bxs`, `tests/init_plan_test.bxs`); the Lua files only parse-checked and the theme loader run against a stub `vim` (no Neovim here); the Starship command logic run in `sh`, not by Starship. **Unverified on a real machine:** the Noctalia IPC argument forms against a running Noctalia, Hyprland's `dofile` and `hl.config` from the managed module and `hyprctl reload` with a Lua config, ghostty's `?` optional include, kitty, alacritty `[general] import` and foot `include=` with a missing file, the foot `[colors-dark]` section on the installed foot, lazy.nvim picking the colourscheme plugin up on `:colorscheme`, `vim-boxlang` loading with `lazy = false`, Starship hiding a custom module on empty output.

### 13.33 Virtual machines: Windows and Linux desktops in containers (decided with the owner 2026-11-13)

- **Command:** `vm list|status [NAME]|size [NAME]|info NAME [--show-password]|doctor|versions linux|windows|create windows [NAME] [--version=V] [--ram=] [--cpus=] [--disk=] [--share=PATH|none]|create linux NAME [--tag=T] [--cpus=] [--memory=] [--share=PATH|none] [--gpu=none|auto|intel|amd|nvidia]|start|stop|logs NAME|open NAME [--web] [--fullscreen]|remove NAME [--keep-data]`, with `--json`. `create` and `remove` are plans until `--yes` (`--dry-run` too). Exit: 0 done, 2 plan or bad usage, 4 precondition (bad name or version, KVM unusable, no engine, no terminal to choose a Windows version on, GPU not possible), 6 a command failed.
- **Two kinds, any number of each.** Every VM has a name (`[a-z0-9-]`, up to 31) and a record in `~/.config/bxcachy/vms/NAME.json` (mode 600). Windows is `dockurr/windows`; a Linux desktop is LinuxServer's `lscr.io/linuxserver/webtop:TAG`. The container is `bxcachy-vm-NAME`, labelled `io.bxcachy.vm`. The first Windows is named `windows`. The engine is the one `bxcachy db engine` chose (Podman by default).
- **Where things live (documented for the user in `docs/guides/vms.md`):** data in `~/.local/share/bxcachy/vms/NAME` (`storage` is the Windows disk, `config` is the Linux desktop's home folder), the record above, the password in the keyring as `BXCACHY_VM_<NAME>_PASSWORD` (`bxcachy secrets`), an app-menu launcher `~/.local/share/applications/bxcachy-vm-NAME.desktop` (runs `vm open NAME`), and a shared folder: `~/Windows` (drive Z:) or `~/Shared` (`/config/Shared`), or `--share=none`. `remove` deletes the container, the data, the password, the record and the launcher; the shared folder is never deleted; `--keep-data` keeps data, password and record. `size` is `du` of the data folder; the images are in the engine (`podman image ls`).
- **Security:** ports bind to `127.0.0.1` only (the webtop terminal has passwordless sudo; the Windows web viewer and RDP are for you). The password is generated (16 random bytes), stored in the keyring, and reaches the container through an env file (mode 600) that is deleted right after `run`. The default `admin` password of dockur is never used.
- **Ports:** Linux 3001 upward (HTTPS, a self-signed certificate: accept it once); Windows web viewer 8006 upward and RDP 3389 upward (TCP and UDP); each VM takes the first port no record uses and nothing listens on.
- **Windows:** `--version` takes any dockur VERSION value (25, `vm versions windows`). Without it at a terminal, a picker shows ten choices with sizes and notes (11 Pro, 11 LTSC, 11 Enterprise, 10 Pro, 10 LTSC, Tiny11, Tiny11 Core, Tiny10, Server 2025 and 2022; the Tiny builds are marked UNOFFICIAL); with no terminal it exits 4 (a script passes `--version`; with `--json` the picker text goes to the terminal device, never stdout). Defaults: RAM half the machine (4G to 8G), CPUs half (2 to 8), disk 64G. Run: `--device /dev/kvm --device /dev/net/tun --cap-add NET_ADMIN --stop-timeout 120`, env `VERSION RAM_SIZE CPU_CORES DISK_SIZE USERNAME PASSWORD`. The install downloads the ISO inside the container on the first start (3 to 8 GB) and takes a while; you need your own Windows license (dockur uses generic trial keys that do not activate). `open` starts the VM if needed, waits for RDP, then runs the first FreeRDP client found (`sdl-freerdp3`, `sdl-freerdp`, `xfreerdp3`, `xfreerdp`, `wlfreerdp3`, `wlfreerdp`) with `/args-from:file:PATH`: a mode 600 file holding `/v:` `/u:` `/p:` `/cert:ignore` `+clipboard` `/dynamic-resolution` `/title:` (and `/f`), so the password is never on a command line; the file is removed after 15 seconds. While Windows is still installing, `open` says so and points at `open --web` (the browser viewer).
- **Linux:** 21 tags from the webtop page (Ubuntu, Debian, Fedora, Arch: xfce, kde, mate, i3, and lxqt for Ubuntu; Alpine with the upstream `latest` tag as `alpine-xfce`); default `ubuntu-xfce`. The `dev` tag and the deprecated Enterprise Linux tags are not offered; KDE tags are Wayland only. Run: `--shm-size 1gb`, env `PUID PGID TZ CUSTOM_USER=bxcachy PASSWORD`, `-v data:/config`. Rootless Podman maps the container's root to you, so PUID and PGID are 0 there (files stay yours); Docker uses your ids. `--cpus` and `--memory` map to the engine flags. When the host has no IPv6 (`/proc/sys/net/ipv6` missing) the container also gets `DISABLE_IPV6=true`, because the image's nginx otherwise fails on `listen [::]` (found by running the real image; `doctor` notes it).
- **GPU (Linux desktops, opt-in):** `intel` and `amd` add `--device /dev/dri` (needs it to exist); `auto` does that when `/dev/dri` exists and nothing otherwise; `nvidia` follows the webtop docs: Docker gets `--runtime nvidia --gpus all --device /dev/nvidia-modeset`, Podman gets CDI (`--device nvidia.com/gpu=all --device /dev/nvidia-modeset`). The Alpine tags refuse NVIDIA. `doctor` reports `/dev/dri`, the NVIDIA driver version (the docs ask for 580 or newer) and `nvidia-ctk`. Windows has no GPU option.
- **Wizard and menu:** two optional questions after the databases: `vm_windows` (none or one of the ten, with descriptions) and `vm_linux` (none or six tags); they become optional steps `vm create windows --version=V` and `vm create linux desktop --tag=T`, and add the Podman install when no engine answer was given. The menu has a Virtual machines entry (list, sizes, doctor, the two version tables).
- **Verified and not:** tested against fake Podman and Docker (every run argument, files, modes, ports, passwords, launchers, exit codes) in `tests/vm-test.sh` and `tests/init_plan_test.bxs`. **Also run for real (2026-11-13, a sandbox with Docker 29.9.2, no KVM, no IPv6, running as root):** `vm create linux` with the real `lscr.io/linuxserver/webtop:ubuntu-xfce` image through `bxcachy`: the published `127.0.0.1:3001` answers 401 without credentials, 200 with the generated password and 401 with a wrong one; the shared folder works both ways; `start`, `stop`, `status`, `size`, `info`, `open` (browser launch only) and `remove` behave. **Never run:** Windows (no `/dev/kvm` here), Podman, a non-root user (so PUID and file ownership are untested), GPUs, FreeRDP. **Unverified on a real machine:** Windows booting under rootless Podman (`/dev/kvm`, `/dev/net/tun`, `NET_ADMIN`), RDP through the published `127.0.0.1` port (dockur documents the container's own IP too), dockur on a Btrfs disk (CachyOS default; not checked in its README), webtop under rootless Podman with PUID 0 and as a non-root Docker user, the NVIDIA paths (driver 580 or newer from a `.run` file per the docs, whether CachyOS's packaged driver counts, CDI on Podman, the Arch package name `nvidia-container-toolkit`), and the FreeRDP argument file (`/args-from:file:` read from the FreeRDP 3 source, the client binary names are a best guess).

### 13.34 The menu, package search and remove (decided with the owner 2026-11-13)

- **Menu skeleton.** `bxcachy menu` follows Omarchy's 11 sections and adds one of ours: Apps, Install, Remove, Appearance, Trigger, Setup, Update, **Develop** (BoxLang, databases, virtual machines, containers, the editor), Agent, Learn, About, System. What used to be top-level BxCachy entries are folded in: Themes into Appearance, Notifications and Screenshot into Trigger, Cloud storage and Settings into Setup, Web apps into Install and Remove. The tree is `MenuTree` (data); `menu items [--json]` prints it, `menu search TEXT [--json]` lists the entries whose path matches with the command each runs (the CLI mirror of the in-menu search). Omarchy's menu has 362 actions; ours had 63 and now has 136 (the Appearance, Trigger, Setup, Update and System depth is still to come, see the parity plan).
- **Search.** The first entry of the top level is `Search…`: one flat list of every entry as a path ("Appearance > Next theme"); the menu provider filters as you type, and the choice runs exactly as it would from its section.
- **Entry kinds:** `sub`, `spawn` (detached), `run` (in a terminal, waits for Enter: output and sudo prompts), `open` (xdg-open a URL), `pick` (choose from a live list, then run with `{}` replaced), `ask` (type a line, then run), `pkgsearch` (type, choose a package from the repos or the AUR, confirm, `pkg install` in a terminal), `catalog` (one catalog group, choose, confirm, `install ID --yes` in a terminal), `db`, `webcreate`, `webrm`. A `confirm` asks before running (reboot, shutdown, logout, every removal). Live lists: themes (the current one marked ✓), your themes, installed browsers, terminals and file managers, explicit packages, installed catalog apps, VMs, installed skills. Providers that cannot take typed text open a terminal that asks (`bxcachy web add`) or say what to type.
- **`pkg`:** `pkg search TEXT [--source=all|repo|aur] [--limit=40]` (pacman -Ss and the AUR RPC v5 `search/TEXT?by=name-desc`; exact names first, then repo packages, then AUR by popularity; installed ones marked; an AUR outage is a note, repo results stay), `pkg info NAME`, `pkg installed [--explicit]`, `pkg install NAME... [--aur] [--yes]` (repo packages through the existing installer steps, AUR packages through `yay -S --needed --noconfirm`; never as root for the AUR, exit 4 without yay; the plan warns that AUR packages are user-submitted scripts and points at `yay -G NAME`), `pkg remove NAME... [--yes]` (`pacman -Rns --noconfirm`, one package at a time). Protected and never removed: base, pacman, sudo, systemd, glibc, bash, coreutils, filesystem, linux-firmware, grub, util-linux, shadow, the keyrings, `linux*` kernels and their headers and NVIDIA modules, and the `cachyos-settings`, `cachyos-hooks` and mirrorlist packages. Not-installed names are a no-op. Names are validated (`[a-z0-9@._+-]`), search text too.
- **`remove ID_OR_PACKAGE...`:** a catalog id removes what installing it put there (pacman, AUR and PKGBUILD apps: their targets through `pkg remove`; web apps: the launcher file); a vendor-script app is reported with exit 4 ("use its own uninstaller"); anything that is not a catalog id is taken as a package name. A plan until `--yes`; your files in `~/.config` and `~/.local` are never touched.
- **`system lock|suspend|logout|reboot|shutdown`:** through `noctalia msg session ...` inside Hyprland with Noctalia (Noctalia IPC docs), else `loginctl lock-session`, `systemctl suspend|reboot|poweroff`, `loginctl terminate-session`. Lock and suspend act at once; logout, reboot and shutdown are a plan until `--yes` (the menu asks first).
- **Verified:** `tests/pkg-test.sh` (fake pacman, yay, curl, sudo, id) and `tests/menu-test.sh` (fake Rofi, Wofi and terminal); `pkg search|info|install|remove` and `remove` were also run against the real Arch repos and the live AUR in the Arch test container (search, install and remove of `cowsay`, `jq` removed by catalog id, protected packages refused). **Not verified:** the menu on a real provider (Rofi, Walker, Fuzzel), AUR installs through `yay`, `system` actions on a real session.

### 13.35 Appearance (decided with the owner 2026-11-13)

- **`bxcachy appearance status|apply`** and verbs `bar show|hide|toggle|position top|bottom|left|right|style opaque|glassy|clear|clock ID|battery on|off`, `dock show|hide|toggle|mode always|autohide|off|position bottom|left|right`, `windows gaps on|off|corners theme|rounded|sharp|opacity opaque|glassy|one-window-ratio on|off`, `animations on|off`, `layout dwindle|scrolling|floating`, `font list|ID|install ID`, `background list|set NAME_OR_PATH|next|random`. Bad usage exits 2, an unknown or not-installed font or image exits 4. All take `--dry-run` and `--json`.
- **State** is `~/.config/bxcachy/appearance.json`; every choice is remembered, so `apply` re-pushes it (after a Noctalia upgrade or on a new session).
- **Noctalia** changes go through `noctalia msg config-set PATH VALUE` (TOML values) on the starter's bar `main`, `[dock]`, `[shell]`, `[widget.clock]` and `[widget.battery]`; show/hide/toggle and wallpapers use `bar-*`, `dock-*`, `wallpaper-*`. Without Noctalia the choice is saved and reported as "saved only", not an error.
- **Hyprland** window looks are one generated file, `~/.config/bxcachy/theme/look.lua`, written through the config service (a file you edited is never overwritten) and loaded by the managed `bxcachy.lua`; it is applied with `hyprctl reload`. `floating` runs `layout float`.
- **Fonts** are the 7 Nerd Fonts we verified; setting one updates Noctalia and every terminal starter you have not edited (your edited terminal configs are kept and reported).
- **Menu:** Appearance has Font, Install a font, Background, Bar, Dock, Windows, Animations, Status and Re-apply beside the theme entries.
- **Verified:** `tests/appearance-test.sh` with fake noctalia, hyprctl, fc-list, pacman and sudo. Not verified on a real machine: Hyprland Lua `dofile` and reload, Noctalia `config-set` persistence and key names.

### 13.36 Display and the developer defaults (decided with the owner 2026-11-13)

- **`bxcachy display list|status`**, `scale NAME auto|0.5..4`, `rotate NAME 0|90|180|270`, `mode NAME preferred|WxH[@R]`, `position NAME auto|XxY`, `mirror on|off`, `laptop on|off`, `brightness up|down|set N`, `apply`, `reset`. Bad usage exits 2, an unknown monitor or a missing tool exits 4. All take `--dry-run` and `--json`.
- **Hyprland:** one generated file, `~/.config/bxcachy/theme/monitors.lua` (a list of `hl.monitor` tables), written through the config service and loaded by the managed `bxcachy.lua` after your own `hyprland.lua`; then `hyprctl reload`. Names come from `hyprctl monitors all -j`. **Plasma:** `kscreen-doctor output.NAME.scale.X|rotation.left|position.X,Y|mode.WxH@R|enable|disable` (90 maps to `left`, 180 to `inverted`, 270 to `right`; unverified on a real machine). State is `~/.config/bxcachy/display.json`.
- **Mirror** shows the laptop panel on every external monitor. **Laptop off** refuses when it would leave no monitor on. Brightness up and down use `noctalia msg brightness-up|down` when Noctalia is there, else `brightnessctl set 5%+|5%-`; `set N` uses `brightnessctl`.
- **Not built:** `laptop auto` (clamshell on lid events). Lid behavior belongs to `bxcachy power`.
- **Menu:** Setup > Display. **Verified:** `tests/display-test.sh` (fake hyprctl JSON, kscreen-doctor, brightnessctl, noctalia).
- **Developer defaults:** Meld (`pacman`, `extra`, verified) is a default of the `editors` profile.

## 14. Install and the setup wizard (decided with the owner 2026-11-10; install, wizard and the init engine are built, the pages' later commands are not)

### 14.1 Install

`bootstrap/install.sh [--yes] [--dry-run]` is the one install command. It prints the plan, asks one `Proceed? [Y/n]` at a terminal (without a terminal it needs `--yes`, else exit 2; `--dry-run` exits 0), then runs, in order: packages with yay and Rust, toolchains (mvm, bvm, BoxLang, nvm and Node, MatchBox), the bxcachy binary, and the core apps (`bxcachy profile-install core --yes`). External installer scripts run without a gate (section 2, rule 8). `install.sh check` is the read-only report; `packages|toolchains|binary|core --yes` re-run one stage. When the wizard exists the install ends by starting it at a terminal.

**Required vs optional toolchains (decided 2026-11-10):** the install always adds BoxLang (Java 21, bvm, mvm, MatchBox, Rust). nvm and Node.js are no longer part of it; they are the optional JavaScript toolchain: `bxcachy toolchain node [--yes] [--dry-run] [--json]` runs the pinned nvm installer from `box.json` `toolchain.nvm` (an external script: its URL is in the plan, it adds nvm to your shell startup files) and `nvm install lts/*`, skipping what is already there. Bun and Deno are catalog apps (`install bun deno`).

### 14.2 `bxcachy init`

A full-screen terminal wizard that asks the questions below, shows a review screen, then runs the matching commands. Answers are saved to `~/.config/bxcachy/answers.json` (mode 600, written atomically); a re-run starts from the saved answers.

```
bxcachy init                          the wizard (needs a terminal)
bxcachy init --answers FILE [--yes] [--dry-run] [--json]    headless: no TUI, the plan from FILE; same --yes / --dry-run rules as every mutating verb
bxcachy init --print-answers          the saved answers
```

Exits: as `setup` (0, 2, 4, 5, 6, 7, 8); 4 also for no terminal without `--answers`. The wizard is only a front end: every answer becomes an ordinary command, so anything it does can be run by hand.

### 14.3 Pages, answers and what they run

**Default desktop (decided 2026-11-10):** Hyprland + Noctalia. KDE Plasma stays installed whatever is chosen but is configured (HyprKwin tiling, shared keys) only for `both` or `plasma`. The login session follows the choice: `hyprland` starts Hyprland, `plasma` starts Plasma, and `both` asks (`login_session`, default Hyprland). `session set` runs for the resulting session. A question may carry `when: { id, in: [...] }` (or `equals`); hidden questions are not asked, not reviewed and not in the answers file.

| Page | Answers (keys in `answers.json`) | Runs or writes |
|---|---|---|
| Desktop | `desktops` (`hyprland` default, `both`, `plasma`), `layout` (`dwindle` tiling default, `master`, `scrolling` carousel, `floating`; asked for Hyprland and Both), `workspaces` (persistent count), `login_session` (`hyprland` or `plasma`, asked only when `desktops` is `both`) | `setup hyprland`, `setup plasma`, `tiling on|off`, `session set` |
| Look | `theme` (`dark`, `light`, `auto`), `wallpaper`, `bar_position`, `world_clocks` (IANA zones with labels) | Noctalia config |
| Input and languages | `keyboard_layouts` (e.g. `us` variant `intl`, `es`), `locale`, `natural_scroll`, `mac_keys` | Hyprland `kb_layout`, KDE keyboard config, locale, `setup xremap` |
| Developer identity | `git_name`, `git_email`, `ssh_key`, `shell` (`zsh` default, `fish`, `bash`; Starship always), `terminal` (`ghostty` default), `terminals_extra`, `editor` | `git config`, `ssh-keygen`, `setup shell`, `setup terminal`, `setup hyprland --terminal` |
| Toolchains | `toolchains` (`java` with gradle and maven, `php` with composer and laravel, `python`, `go`, `javascript`), `js_runtimes` (`node` with nvm default, `bun`, `deno`; asked only when `javascript` is chosen). BoxLang is always installed (shown as a note) | catalog profiles, `toolchain node`, `install bun deno` |
| Containers | `container_engine` (`podman` default, `docker`) | package and service setup |
| Databases | `databases` (PostgreSQL, MySQL, MariaDB, Redis, MongoDB, Couchbase, pgvector, Chroma, Qdrant, Weaviate, Meilisearch, OpenSearch, Elasticsearch; none preselected; Milvus is not supported) | `db engine`, `db start` per service |
| AI (own page, after Apps) | `ai_agents` (claude-code, codex-cli, gemini-cli), `ai_default`, `ai_orchestrators` (`pane` default, `orca`, `herdr`), `ai_local` (ollama, lm-studio, jan, koboldcpp, gpt4all; nothing preselected), `ai_local_gpu` (`none`, `nvidia`, `amd`; only with Ollama), `ai_keys` (`later` default, `now`), `ai_global_keys` (only with `now`; default none) | installs through `install`; then `secrets setup`, one optional `secrets set KEY` per single-provider agent plus per ticked provider (`ai_providers`) when `now` (typed hidden at the terminal, skippable; never saved in answers.json), optional `secrets global on KEY`, and `ai default ID` |
| VPN | `vpn` (Tailscale, WireGuard, OpenVPN, Mullvad, Proton) | catalog and services |
| Password manager | `password_manager` (Bitwarden, 1Password, KeePassXC) | catalog |
| Gaming | `gaming` (`none`, `steam`, `bundle`) | catalog (CachyOS gaming bundle) |
| Apps | `app_mode` (`defaults` = Basic, or `custom` = Customize), `apps_<group>_<category>` lists (Customize only), `default_browser` (the terminal you picked becomes the default terminal), `launcher` (`noctalia` default, `walker`, `rofi`, `fuzzel`, `wofi`; asked for Hyprland and Both), `menu` (`rofi` default, `walker`, `fuzzel`, `wofi`) | `install` (the provider's package), `runner set`, `runner menu-set` |
| Backups and storage | `snapshots`, `backup_target` (restic or borg), `mounts`, `cache_cleanup` | snapper, timers |
| Import | `dotfiles_repo` (the method is detected, not asked) | `dotfiles apply` (last step) |

Fonts are not a question: the install always adds JetBrains Mono, JetBrains Mono Nerd, the Powerline fonts and the Nerd Fonts symbols (with the Noto fonts `setup hyprland` already installs).

**Built (W4):** `init`, `init --answers`, `init --print-answers`. The planner (`InitPlan`, pure) turns answers into this ordered list, one ordinary command each, run through the program itself with `--yes`: `setup hyprland [--terminal --layout]`, `setup plasma`, `setup terminal`, `setup shell`, `setup xremap`, `install` (AI orchestrators and agents), `git config --global` (name, email), and last `session set`. A missing answer adds no step. A step that fails stops the rest (exit 7 when some were done, else that step's exit code; the others are `skipped`). Also run: `profile-install jvm|php|python|go` per toolchain (`composer global require laravel/installer` after PHP; JavaScript runs `toolchain node` for Node.js with nvm, and Bun and Deno join the `install`), `profile-install containers` (Podman) or `install docker`, `profile-install gaming` (bundle) or `install steam`, and one `install` for the AI tools, VPN (`tailscale`, `wireguard`, `openvpn`, `mullvad`, `proton-vpn`), password manager and backup tools (`snapper` with `snap-pac`, `restic`, `borg`). Databases: `db engine` remembers the container engine (`container_engine`), then `db start ENGINE` runs for each picked service (none is preselected); `database_passwords` (`generate` default: "Generated (recommended)", or `ask`: "My own password"; the question appears once a database is picked) adds `--ask-password` for the engines that have a password (the typed password is never stored in `answers.json`; asking needs a terminal, so a headless `init` with `ask` fails that step with exit 4). Apps: Basic runs `install --shell=...`; Customize runs one `install` with the ticked apps (filtered by desktop); then `default browser` and `default terminal`. Answers whose command does not exist yet (`ssh_key`; and `workspaces`, `natural_scroll`, `layouts`, `theme`, `wallpaper` when Hyprland is not being set up, because only the Hyprland starter takes them) are saved and listed as `pending`, never dropped silently. `init` at a terminal runs the wizard, saves `answers.json`, then runs the plan (the review screen is the confirmation; `--dry-run` only prints). `install.sh` ends with `bxcachy init` at a terminal and prints a hint otherwise.

### 14.4 Rules

- Every answer is optional; an unanswered page does nothing. The review screen lists exactly the commands that will run.
- `init` never runs a step the user did not choose, and never overwrites a file the user changed (the config service rules of section 6 apply).
- Starter configs are parametrized by the answers (workspaces, window style, layouts, theme, wallpaper, bar position, world clocks, natural scroll); the defaults are the current starters.
- Databases follow the earlier plan (`plan.md` section 7): Podman is the default engine and Docker is an explicit choice; services run as containers with start, stop, status and logs, persistent volumes and generated passwords kept in a mode-600 file.
- Runner integration (legacy `bxcachy-runner`): launcher providers `system`, `noctalia`, `rofi`, `walker`, `krunner`, `vicinae`, `hyprrunner`, `custom`; menu providers `rofi`, `walker`, `vicinae`, `hyprrunner`; commands are JSON argument arrays, never shell strings; keybindings are never changed. Default on Hyprland is Noctalia (Super+Space).
- The TUI needs MatchBox's `bif-tui` in the native runner (task W2). Until then `init --answers` is the only form.

### 14.5 Tasks

W1 this section; W2 native TUI in MatchBox; W3 `install.sh` (done); W4 init engine (planner and headless run); W5 catalog additions; W6 parametrized starters; W7 TUI pages; W8 CI and docs; W9 `bxcachy db`; W10 dotfiles import; W11 `bxcachy runner`.

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

- **Starship is the one prompt for every shell.** `setup shell` installs the shell's packages in one `sudo pacman` call, writes `~/.config/starship.toml` once (BoxLang green and cyan on Catppuccin Frappe, Nerd Font symbols; yours afterwards), and makes the chosen shell the login shell with `sudo chsh`. No Oh My Zsh and no plugin manager: plugins are pacman packages.
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
bxcachy db start ENGINE [--name N] [--port P] [--yes] [--dry-run]    create, or start a stopped one; never replaces a container
bxcachy db stop|status|logs ENGINE [--name N]
bxcachy db remove ENGINE [--name N] [--delete-data] --yes            removes the container; the data volume stays unless --delete-data
bxcachy db info ENGINE [--name N] [--show-password]                  where it listens and how to connect (password masked by default)
bxcachy db engine [podman|docker]                                    which engine runs them (podman by default, saved in ~/.config/bxcachy/db.json)
bxcachy db menu                                                      the control center, on the runner's menu provider (needs a terminal program)
```

Exit codes: 0 done, 2 usage or no `--yes` (the plan is printed; `--dry-run` exits 0), 4 precondition (no container engine, unknown or unsupported engine, bad name or port, `vm.max_map_count` too low), 6 the container command failed. `--json` gives the standard envelope.

**Rules.** Services listen on `127.0.0.1` only. A container that exists is never replaced (a stopped one is started; a running one is left alone). Containers are named `bxcachy-db-<engine>-<name>` (name defaults to `default`; letters, digits and hyphens) and labelled `io.bxcachy.database=true`. Data lives in a **named volume** with the container's name, not a host folder: rootless containers cannot write to a bind-mounted folder as the image's own user (OpenSearch, Elasticsearch and Meilisearch run as non-root). Generated passwords (24 random bytes as hex) go in `~/.local/share/bxcachy/databases/<container>/` (`password` and `database.env`, mode 600, plus `meta.json` with the port) and reach the container through `--env-file`, never on a command line. Nothing changes system settings: when `vm.max_map_count` is too low `start` stops with the `sudo sysctl -w` line to run. Images are pinned and were checked on Docker Hub on 2026-11-10 (Elasticsearch's from Elastic's docs).

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

### 13.8 Tests and what is verified

- Pure `SetupPlan`, `Shortcuts`, `NoctaliaConfig` classes with script tests; native tests with fake `pacman`, `yay`, `git`, `qdbus6`, `kwriteconfig6`, `sudo`, `systemctl` (plan output, `--yes` gating, root refusal, partial failure, re-run, undo, drift, one clean `--json` envelope); the starter TOML and JSON are parsed.
- The real Arch container (`tests/arch/suite.sh`) runs the xremap plan, checks the AUR package names, runs the whole `setup hyprland`, checks the written files, byte-identical wallpapers, `keys check`, and has Hyprland verify the starter config.
- Not verifiable in CI: HyprKwin's installer (needs a running KWin), xremap's per-app rules on both builds, Noctalia accepting every config key, and the exact Hyprland bind strings on a running session. These are covered by the owner's acceptance run on a real CachyOS KDE machine.

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
| AI agents | `ai_default`, `ai_install`, `ai_orchestrators` (`pane` default, `orca`, `herdr`) | catalog (category Coding orchestration: AUR `pane-bin`, `stably-orca-bin`, `herdr-bin`) |
| VPN | `vpn` (Tailscale, WireGuard, OpenVPN, Mullvad, Proton) | catalog and services |
| Password manager | `password_manager` (Bitwarden, 1Password, KeePassXC) | catalog |
| Gaming | `gaming` (`none`, `steam`, `bundle`) | catalog (CachyOS gaming bundle) |
| Apps | `app_mode` (`defaults` or `custom`), `app_selection` per category, `default_browser`, `default_terminal`, `launcher` (`noctalia` default, `walker`, `rofi`, `fuzzel`, `wofi`; asked for Hyprland and Both), `menu` (`rofi` default, `walker`, `fuzzel`, `wofi`) | `install` (the provider's package), `runner set`, `runner menu-set` |
| Backups and storage | `snapshots`, `backup_target` (restic or borg), `mounts`, `cache_cleanup` | snapper, timers |
| Import | `dotfiles_repo`, `dotfiles_method` (`chezmoi`, `yadm`, `stow`, `links`) | dotfiles import (last step) |

Fonts are not a question: the install always adds JetBrains Mono, JetBrains Mono Nerd, the Powerline fonts and the Nerd Fonts symbols (with the Noto fonts `setup hyprland` already installs).

**Built (W4):** `init`, `init --answers`, `init --print-answers`. The planner (`InitPlan`, pure) turns answers into this ordered list, one ordinary command each, run through the program itself with `--yes`: `setup hyprland [--terminal --layout]`, `setup plasma`, `setup terminal`, `setup shell`, `setup xremap`, `install` (AI orchestrators and agents), `git config --global` (name, email), and last `session set`. A missing answer adds no step. A step that fails stops the rest (exit 7 when some were done, else that step's exit code; the others are `skipped`). Also run: `profile-install jvm|php|python|go` per toolchain (`composer global require laravel/installer` after PHP; JavaScript runs `toolchain node` for Node.js with nvm, and Bun and Deno join the `install`), `profile-install containers` (Podman) or `install docker`, `profile-install gaming` (bundle) or `install steam`, and one `install` for the AI tools, VPN (`tailscale`, `wireguard`, `openvpn`, `mullvad`, `proton-vpn`), password manager and backup tools (`snapper` with `snap-pac`, `restic`, `borg`). Databases: `db engine` remembers the container engine (`container_engine`), then `db start ENGINE` runs for each picked service (none is preselected). Answers whose command does not exist yet (`ssh_key`, `app_mode`; and `workspaces`, `natural_scroll`, `layouts`, `theme`, `wallpaper` when Hyprland is not being set up, because only the Hyprland starter takes them) are saved and listed as `pending`, never dropped silently. `init` at a terminal runs the wizard, saves `answers.json`, then runs the plan (the review screen is the confirmation; `--dry-run` only prints). `install.sh` ends with `bxcachy init` at a terminal and prints a hint otherwise.

### 14.4 Rules

- Every answer is optional; an unanswered page does nothing. The review screen lists exactly the commands that will run.
- `init` never runs a step the user did not choose, and never overwrites a file the user changed (the config service rules of section 6 apply).
- Starter configs are parametrized by the answers (workspaces, window style, layouts, theme, wallpaper, bar position, world clocks, natural scroll); the defaults are the current starters.
- Databases follow the earlier plan (`plan.md` section 7): Podman is the default engine and Docker is an explicit choice; services run as containers with start, stop, status and logs, persistent volumes and generated passwords kept in a mode-600 file.
- Runner integration (legacy `bxcachy-runner`): launcher providers `system`, `noctalia`, `rofi`, `walker`, `krunner`, `vicinae`, `hyprrunner`, `custom`; menu providers `rofi`, `walker`, `vicinae`, `hyprrunner`; commands are JSON argument arrays, never shell strings; keybindings are never changed. Default on Hyprland is Noctalia (Super+Space).
- The TUI needs MatchBox's `bif-tui` in the native runner (task W2). Until then `init --answers` is the only form.

### 14.5 Tasks

W1 this section; W2 native TUI in MatchBox; W3 `install.sh` (done); W4 init engine (planner and headless run); W5 catalog additions; W6 parametrized starters; W7 TUI pages; W8 CI and docs; W9 `bxcachy db`; W10 dotfiles import; W11 `bxcachy runner`.

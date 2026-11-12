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
- **Settings:** defaults, shortcuts, launcher check, setup status, dotfiles status (read-only views in a terminal).
- Every entry is started without `--yes`, so nothing is changed by the menu itself; the commands keep their own plan/`--yes` rules. Back and Exit are the last entry of each level; cancelling the provider (empty answer) leaves the menu with exit 0.
- Terminals for `run` entries: the first installed of ghostty, kitty, foot, alacritty, konsole (`-e` for ghostty, alacritty, konsole). Exit 4 when there is no menu program, or no terminal for a `run` entry.
- Hyprland binds it to `Super+Alt+Space` in the shortcut table. Tests: `tests/menu-test.sh` (fake Rofi and terminal).

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
- Catalog: `btrfs-assistant` and `timeshift` (both `extra`, verified 2026-11-12) are in the default tier, so a plain `install` and Basic mode install them. Btrfs Assistant only helps on a Btrfs disk. Omarchy's base package list has none of restic, borg, snapper, snap-pac, timeshift or btrfs-assistant (checked in `install/omarchy-base.packages`, 2026-11-12).

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

---
title: Command reference
order: 1
summary: Every bxcachy command with its usage, examples and exit codes.
---

# Command reference

Every command is `bxcachy NAME ...`. This page is generated from `docs/reference/cli.json`; the same data answers `bxcachy help` and `bxcachy help NAME` in the terminal. The [command contract](../architecture/COMMAND-CONTRACT.md) has the details behind each one.

## How commands behave

| Flag | What it does |
|---|---|
| `--json` | Print one JSON object instead of text (see below). Every command takes it. |
| `--yes` | Apply a change that installs packages or edits system files. Without it you get the plan and exit code 2. |
| `--dry-run` | Print the plan or the exact commands and exit 0. Nothing is changed. |
| `--force` | Where it exists: replace a file BxCachy would otherwise keep because you edited it. |

Settings that only touch your own config (a theme, the bar, the font) act at once and need no `--yes`.

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Done, or nothing to do (also `--dry-run`). |
| 1 | A check came out negative (for example `package-status` says it is missing). |
| 2 | Usage error, or a plan was printed because `--yes` was not given. |
| 3 | Timeout, or the item is not available. |
| 4 | A precondition failed: not Arch or CachyOS, a tool or a monitor that is not there, an unknown name. |
| 5 | The official (pacman) phase failed. |
| 6 | The AUR phase, or the command you asked for, failed. |
| 7 | Partial success: some items were done, some failed. |
| 8 | Config conflict: a file you edited, or another run is in progress. |
| 9 | Internal error. |
| 10 | `update check`: an update is available. |

### JSON

```json
{ "schema": 1, "command": "dns", "version": "0.11.0", "ok": true, "exit": 0, "dry_run": false, "data": { }, "warnings": [] }
```

`data` is different for every command; `ok` is true when `exit` is 0. Scripts should read `exit` and `data`, never the text.

## All commands

**Start here**: [`init`](#bxcachy-init), [`refresh`](#bxcachy-refresh), [`reinstall`](#bxcachy-reinstall), [`wizard`](#bxcachy-wizard), [`status`](#bxcachy-status), [`doctor`](#bxcachy-doctor), [`update`](#bxcachy-update), [`version`](#bxcachy-version), [`menu`](#bxcachy-menu), [`apps`](#bxcachy-apps), [`help`](#bxcachy-help)

**Install and remove**: [`install`](#bxcachy-install), [`remove`](#bxcachy-remove), [`pkg`](#bxcachy-pkg), [`catalog`](#bxcachy-catalog), [`plan`](#bxcachy-plan), [`install-plan`](#bxcachy-install-plan), [`optional-plan`](#bxcachy-optional-plan), [`profile-plan`](#bxcachy-profile-plan), [`profile-install-plan`](#bxcachy-profile-install-plan), [`profile-install`](#bxcachy-profile-install), [`optional-install`](#bxcachy-optional-install), [`profile-list`](#bxcachy-profile-list), [`optional-list`](#bxcachy-optional-list), [`desktop-list`](#bxcachy-desktop-list), [`tui-list`](#bxcachy-tui-list), [`web-list`](#bxcachy-web-list), [`package-status`](#bxcachy-package-status), [`package-source`](#bxcachy-package-source), [`dev-plan`](#bxcachy-dev-plan), [`prerequisites`](#bxcachy-prerequisites), [`apps-doctor`](#bxcachy-apps-doctor), [`web`](#bxcachy-web), [`toolchain`](#bxcachy-toolchain)

**Desktop setup**: [`setup`](#bxcachy-setup), [`session`](#bxcachy-session), [`tiling`](#bxcachy-tiling), [`plasma`](#bxcachy-plasma), [`keys`](#bxcachy-keys), [`runner`](#bxcachy-runner), [`default`](#bxcachy-default), [`layout`](#bxcachy-layout), [`assets`](#bxcachy-assets), [`config`](#bxcachy-config)

**Look and feel**: [`theme`](#bxcachy-theme), [`appearance`](#bxcachy-appearance), [`display`](#bxcachy-display), [`power`](#bxcachy-power), [`time`](#bxcachy-time), [`toggle`](#bxcachy-toggle), [`nightshift`](#bxcachy-nightshift), [`notify`](#bxcachy-notify)

**System and security**: [`system`](#bxcachy-system), [`security`](#bxcachy-security), [`dns`](#bxcachy-dns), [`kernel`](#bxcachy-kernel), [`ssh`](#bxcachy-ssh), [`secrets`](#bxcachy-secrets), [`vpn`](#bxcachy-vpn), [`cloud`](#bxcachy-cloud), [`settings`](#bxcachy-settings), [`dotfiles`](#bxcachy-dotfiles), [`nas`](#bxcachy-nas), [`backup`](#bxcachy-backup), [`timemachine`](#bxcachy-timemachine), [`java`](#bxcachy-java), [`sdk`](#bxcachy-sdk), [`tui`](#bxcachy-tui), [`bxtimemachine`](#bxcachy-bxtimemachine)

**Develop**: [`boxlang`](#bxcachy-boxlang), [`editor`](#bxcachy-editor), [`db`](#bxcachy-db), [`containers`](#bxcachy-containers), [`vm`](#bxcachy-vm), [`ai`](#bxcachy-ai), [`skills`](#bxcachy-skills)

**Everyday tools**: [`screenshot`](#bxcachy-screenshot), [`qr`](#bxcachy-qr), [`record`](#bxcachy-record), [`clipboard`](#bxcachy-clipboard), [`emoji`](#bxcachy-emoji), [`forcequit`](#bxcachy-forcequit), [`window`](#bxcachy-window), [`overview`](#bxcachy-overview), [`quicklook`](#bxcachy-quicklook), [`dolphin`](#bxcachy-dolphin), [`dictation`](#bxcachy-dictation), [`strata`](#bxcachy-strata), [`gpu`](#bxcachy-gpu), [`input`](#bxcachy-input), [`airplay`](#bxcachy-airplay)

## Start here

Set up the machine, see where it stands, keep it current.

### `bxcachy init` {#bxcachy-init}

The setup wizard: asks the questions, shows a review, then runs the matching commands.

```text
bxcachy init [--from=FILE] [--fresh | --rerun] | init --answers=FILE [--yes] [--dry-run] [--json] | init --print-answers [--from-system] [--json] | init --export=FILE [--force]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy init
bxcachy init --answers=answers.json --yes
bxcachy init --print-answers --from-system --json
```

### `bxcachy refresh` {#bxcachy-refresh}

Put a managed config back to what BxCachy ships, with a backup first and without installing anything.

```text
bxcachy refresh hyprland|noctalia|terminals|shell|nvim|theme|all [--starter] [--force] [--yes] [--dry-run] [--json]
bxcachy refresh list [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy refresh list
bxcachy refresh terminals --dry-run
bxcachy refresh hyprland --yes
bxcachy refresh shell --yes --force
```

> A file you edited is kept and reported; --force overwrites it after a backup (see config history and config restore). --starter also rewrites the starter hyprland.lua or Noctalia config.toml, which are yours.

### `bxcachy reinstall` {#bxcachy-reinstall}

Run the setup wizard again from your saved answers (the same as init --rerun).

```text
bxcachy reinstall [--yes] [--dry-run] [--json]
```

```bash
bxcachy reinstall
```

> This is the way to install packages again. refresh only puts config files back.

### `bxcachy wizard` {#bxcachy-wizard}

Wizard pieces for scripts: render the demo screens or a pages file.

```text
bxcachy wizard --demo [--out=FILE] | --pages=FILE [--out=FILE] [--answers=FILE]
```

```bash
bxcachy wizard --demo
```

### `bxcachy status` {#bxcachy-status}

What is installed and configured on this machine, compared with what BxCachy would do.

```text
bxcachy status [--json]
```

```bash
bxcachy status
bxcachy status --json
```

### `bxcachy doctor` {#bxcachy-doctor}

Checks the machine (Arch or CachyOS, pacman, sudo, disk) and reports problems.

```text
bxcachy doctor [--json]
```

```bash
bxcachy doctor
```

### `bxcachy update` {#bxcachy-update}

Check for a BxCachy update, apply it, pick a channel, turn the daily notification on or off.

```text
bxcachy update check [--notify] | apply [--yes] | channel [stable|beta] | notifications on|off|status [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy update check
bxcachy update apply --yes
bxcachy update channel beta
bxcachy update notifications on
```

> Exit 10 from `update check` means an update is available.

### `bxcachy version` {#bxcachy-version}

The BxCachy version and build.

```text
bxcachy version [--json]
```

```bash
bxcachy version
```

### `bxcachy menu` {#bxcachy-menu}

The control center: every command as a menu on your launcher (Rofi, Walker, Wofi, Fuzzel or Vicinae).

```text
bxcachy menu | menu items [--json] | menu search TEXT [--json]
```

```bash
bxcachy menu
bxcachy menu search 'time zone'
```

> Bind it to a key; the first entry, Search, lists every entry as one flat list.

### `bxcachy apps` {#bxcachy-apps}

Your installed catalog apps, as a list or a launcher grid.

```text
bxcachy apps | apps list [--json]
```

```bash
bxcachy apps list
```

### `bxcachy help` {#bxcachy-help}

This list, or the usage of one command.

```text
bxcachy help [COMMAND]
```

```bash
bxcachy help
bxcachy help appearance
```

## Install and remove

Apps from the catalog, any package from the repositories or the AUR, and the reverse.

### `bxcachy install` {#bxcachy-install}

Install catalog apps by id (or a whole group or profile).

```text
bxcachy install [NAME] [--optional] [--shell=hyprland|plasma|all] [--json] [--yes] [--dry-run]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy install --dry-run
bxcachy install --yes
```

> With no name it installs the default set; without --yes it prints the plan and changes nothing.

### `bxcachy remove` {#bxcachy-remove}

Uninstall catalog apps (their packages or web launchers).

```text
bxcachy remove ID_OR_PACKAGE... [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy remove lazygit --yes
```

> Protected packages (the base system, the kernel, bxcachy itself) are refused.

### `bxcachy pkg` {#bxcachy-pkg}

Search, inspect, install and remove any package from the repositories and the AUR.

```text
bxcachy pkg search TEXT [--source=all|repo|aur] [--limit=N] | info NAME | installed [--explicit] | install NAME... [--aur] [--yes] [--dry-run] | remove NAME... [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy pkg search ripgrep
bxcachy pkg install ripgrep --yes
bxcachy pkg remove htop --yes
```

### `bxcachy catalog` {#bxcachy-catalog}

Browse the app catalog.

```text
bxcachy catalog list [--group=G] [--category=C] [--tier=default|optional] [--kind=K] [--source=S] [--json] | show ID | groups | check | version
```

```bash
bxcachy catalog groups
bxcachy catalog list --group=ai --tier=default
bxcachy catalog show lazygit
```

### `bxcachy plan` {#bxcachy-plan}

Show what installing would do, without doing it.

```text
bxcachy plan [NAME] [--optional] [--shell=hyprland|plasma|all] [--json]
```

```bash
bxcachy plan
bxcachy plan --shell=hyprland --json
```

### `bxcachy install-plan` {#bxcachy-install-plan}

The install plan for the selection (same as plan).

```text
bxcachy install-plan [NAME] [--optional] [--shell=hyprland|plasma|all] [--json]
```

### `bxcachy optional-plan` {#bxcachy-optional-plan}

The plan for the optional apps.

```text
bxcachy optional-plan [--shell=hyprland|plasma|all] [--json]
```

### `bxcachy profile-plan` {#bxcachy-profile-plan}

The plan for one profile.

```text
bxcachy profile-plan NAME [--optional] [--shell=hyprland|plasma|all] [--json]
```

```bash
bxcachy profile-plan jvm
```

### `bxcachy profile-install-plan` {#bxcachy-profile-install-plan}

The install steps for one profile.

```text
bxcachy profile-install-plan NAME [--optional] [--shell=hyprland|plasma|all] [--json]
```

### `bxcachy profile-install` {#bxcachy-profile-install}

Install a profile (jvm, containers, terminal, editors, ...).

```text
bxcachy profile-install NAME [--optional] [--shell=hyprland|plasma|all] [--json] [--yes] [--dry-run]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy profile-install terminal --yes
```

### `bxcachy optional-install` {#bxcachy-optional-install}

Install the optional apps of the catalog.

```text
bxcachy optional-install [--shell=hyprland|plasma|all] [--json] [--yes] [--dry-run]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

### `bxcachy profile-list` {#bxcachy-profile-list}

List the profiles.

```text
bxcachy profile-list [--json]
```

### `bxcachy optional-list` {#bxcachy-optional-list}

List the optional apps.

```text
bxcachy optional-list [--json]
```

### `bxcachy desktop-list` {#bxcachy-desktop-list}

List the desktop apps in the catalog.

```text
bxcachy desktop-list [--json]
```

### `bxcachy tui-list` {#bxcachy-tui-list}

List the terminal apps in the catalog.

```text
bxcachy tui-list [--json]
```

### `bxcachy web-list` {#bxcachy-web-list}

List the web apps in the catalog.

```text
bxcachy web-list [--json]
```

### `bxcachy package-status` {#bxcachy-package-status}

Whether a catalog app is installed.

```text
bxcachy package-status ID
```

```bash
bxcachy package-status lazygit
```

### `bxcachy package-source` {#bxcachy-package-source}

Where a catalog app comes from (pacman, AUR, PKGBUILD, web).

```text
bxcachy package-source ID
```

```bash
bxcachy package-source lazygit
```

### `bxcachy dev-plan` {#bxcachy-dev-plan}

What the developer toolchain install would use: Java 21, Maven, Gradle, BVM, MVM.

```text
bxcachy dev-plan
```

### `bxcachy prerequisites` {#bxcachy-prerequisites}

What BxCachy needs on the machine before anything else.

```text
bxcachy prerequisites [--json]
```

### `bxcachy apps-doctor` {#bxcachy-apps-doctor}

Checks the catalog apps for missing or broken installs.

```text
bxcachy apps-doctor [--json]
```

### `bxcachy web` {#bxcachy-web}

Web apps: create one from a URL, install a set (Google, Microsoft, Apple, BoxLang).

```text
bxcachy web add [NAME URL] [--browser=brave|chromium|google-chrome|edge|firefox] [--yes] | list | rm NAME [--yes] | install google|microsoft|apple|boxlang|all [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy web add Notes https://notes.example.com --yes
bxcachy web install google --yes
bxcachy web rm Notes --yes
```

### `bxcachy toolchain` {#bxcachy-toolchain}

Language toolchains outside the always-installed BoxLang one (Node via nvm, Rust, Python, Go, PHP).

```text
bxcachy toolchain node [--yes] [--dry-run] [--json]   (Bun and Deno: bxcachy install bun deno)
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy toolchain node --yes
```

## Desktop setup

Hyprland with Noctalia, or KDE Plasma beside it: the session, the keys, the defaults.

### `bxcachy setup` {#bxcachy-setup}

Set up a desktop: Hyprland with Noctalia, Plasma with HyprKwin tiling, terminals, keyboards, status.

```text
bxcachy setup plasma [--keys | --undo-keys] | hyprland [--terminal=ghostty|kitty|alacritty|foot|konsole] [--layout=dwindle|master|scrolling|floating] [--workspaces=N] [--natural-scroll] [--layouts=us-intl,es] [--theme=dark|light|auto] [--wallpaper=box|grid|aurora|minimal] | terminal [--default=ghostty] [--also=a,b] | shell [--shell=zsh|fish|bash] | keyboard [--layouts=us-intl,es] | xremap [--build=hypr|kde] | undo plasma|hyprland|xremap | status [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy setup hyprland --yes
bxcachy setup terminal --default=ghostty --also=kitty --yes
```

### `bxcachy session` {#bxcachy-session}

Which desktop SDDM starts: Hyprland or Plasma.

```text
bxcachy session show | set hyprland|plasma [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy session show
```

### `bxcachy tiling` {#bxcachy-tiling}

Tiling inside Plasma (HyprKwin): on, off, status, layouts.

```text
bxcachy tiling on|off|status | layout [dwindle|master|monocle|scrolling|stage] [--json]
```

```bash
bxcachy tiling on
bxcachy tiling layout dwindle
```

### `bxcachy plasma` {#bxcachy-plasma}

Plasma extras: panel layouts (apply, undo, status) and the islands preset.

```text
bxcachy plasma panels apply [--agenda] [--without-weather] [--desktops=N] [--preset=NAME] | undo | status [--yes] [--dry-run] [--json]  |  plasma desktops N [--yes]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy plasma panels apply --preset=islands --yes
bxcachy plasma desktops 4 --yes
```

### `bxcachy keys` {#bxcachy-keys}

The shortcut table: show, check conflicts, apply to Hyprland and Plasma, Mac-style keys.

```text
bxcachy keys show | mac [on|off|status] [--yes] | set ID KEYS [--yes] [--force] | reset ID [--yes] | conflicts | render xremap|hyprland|plasma | check | apply [--yes] [--dry-run] [--force] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy keys show
bxcachy keys set emoji Super+Ctrl+E --yes
bxcachy keys mac on --yes
bxcachy keys conflicts
```

### `bxcachy runner` {#bxcachy-runner}

Which launcher and which menu program BxCachy uses (Rofi, Walker, Wofi, Fuzzel, Vicinae).

```text
bxcachy runner list | show | doctor | launch | select JSON_ENTRIES [--prompt=TEXT] | set PROVIDER | menu-set PROVIDER | launcher-command PROVIDER JSON_ARGV | menu-command PROVIDER JSON_ARGV [--json]
```

```bash
bxcachy runner list
bxcachy runner set rofi
bxcachy runner doctor
```

### `bxcachy default` {#bxcachy-default}

Default apps: browser, terminal, file manager.

```text
bxcachy default show | browser ID | terminal ID | filemanager ID [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy default show
bxcachy default browser brave --yes
```

### `bxcachy layout` {#bxcachy-layout}

Window layout at runtime: tile or float (toggle).

```text
bxcachy layout [toggle|float|tile|status] [--dry-run] [--json]
```

```bash
bxcachy layout toggle
```

### `bxcachy assets` {#bxcachy-assets}

Brand assets (logo, icon, wallpapers): list, or install them.

```text
bxcachy assets list | install [--yes] [--dry-run] [--json]
```

```bash
bxcachy assets list
```

### `bxcachy config` {#bxcachy-config}

The managed config files: list, diff, apply, restore a backup, history. A file you edited is never overwritten.

```text
bxcachy config list|diff NAME|apply NAME|restore NAME ID|history [NAME] [--yes] [--dry-run] [--force] [--json]
bxcachy config restore NAME ID --yes
```

```bash
bxcachy config list
bxcachy config diff hypr/bxcachy.lua
bxcachy config history
```

> BxCachy never overwrites a file you edited; `config status` shows which ones are yours.

## Look and feel

Themes, fonts, bar, dock, windows, monitors and power.

### `bxcachy theme` {#bxcachy-theme}

Themes: 15 bundled (10 from Omarchy, 5 BxCachy), set one, light or dark, install from git.

```text
bxcachy theme list | show NAME | set NAME [--mode=theme|dark|light|auto] [--keep-wallpaper] | random | next | mode theme|dark|light|auto | install GIT_URL [--name=N] [--force] | import PATH [--name=N] [--force] | remove NAME | vscode [--yes] [--dry-run] | status [--dry-run] [--json]
```

```bash
bxcachy theme list
bxcachy theme set tokyo-night --mode=dark
bxcachy theme install https://github.com/user/theme --name=mine
bxcachy theme mode auto
bxcachy theme vscode --yes
```

> A theme colours the bar, terminals, btop, Neovim, GTK and Qt apps, tmux, fzf, launchers and (on Plasma) the colour scheme. VS Code is opt-in.

### `bxcachy appearance` {#bxcachy-appearance}

Bar, dock, windows, animations, layout, fonts and backgrounds, one setting at a time.

```text
bxcachy appearance status|apply [--json]
bxcachy appearance bar show|hide|toggle | position top|bottom|left|right | style opaque|glassy|clear | clock ID | battery on|off
bxcachy appearance dock show|hide|toggle | mode always|autohide|off | position bottom|left|right
bxcachy appearance windows gaps on|off | corners theme|rounded|sharp | opacity opaque|glassy | one-window-ratio on|off
bxcachy appearance animations on|off
bxcachy appearance layout dwindle|scrolling|floating
bxcachy appearance font list | ID | install ID [--yes]
bxcachy appearance background list | set NAME_OR_PATH | next | random
```

```bash
bxcachy appearance bar position bottom
bxcachy appearance windows gaps off
bxcachy appearance font install cascadia --yes
bxcachy appearance background random
```

> Settings act at once (no --yes); --dry-run shows the commands. What you choose is remembered, and `appearance apply` pushes it again.

### `bxcachy display` {#bxcachy-display}

Monitors: scale, rotation, mode, position, mirroring the laptop panel, turning it off, brightness.

```text
bxcachy display list|status [--json]
bxcachy display scale NAME auto|0.5..4
bxcachy display rotate NAME 0|90|180|270
bxcachy display mode NAME preferred|WxH[@R]
bxcachy display position NAME auto|XxY
bxcachy display mirror on|off
bxcachy display laptop on|off
bxcachy display brightness up|down|set N
bxcachy display apply | reset
```

```bash
bxcachy display list
bxcachy display scale DP-2 1.5
bxcachy display mirror on
bxcachy display brightness set 40
```

> On Hyprland it writes theme/monitors.lua and reloads; on Plasma it uses kscreen-doctor.

### `bxcachy power` {#bxcachy-power}

Laptop power: profile, lid action, setup of the power tools, doctor.

```text
bxcachy power status [--json]
bxcachy power profile [performance|balanced|saver]
bxcachy power lid suspend|lock|ignore [--yes]
bxcachy power setup [--yes] [--force]
bxcachy power doctor [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy power profile saver
bxcachy power lid lock --yes
bxcachy power doctor
```

> `power setup` does nothing on a machine without a battery unless you add --force.

### `bxcachy time` {#bxcachy-time}

The time zone: show, set, set from your IP after travelling, follow your location, network time.

```text
bxcachy time status [--json]
bxcachy time zone [--list | ZONE] [--yes]
bxcachy time sync [--yes]
bxcachy time auto on|off|status [--yes]
bxcachy time ntp on|off [--yes]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy time zone Europe/Madrid --yes
bxcachy time sync --yes
bxcachy time auto on --yes
```

> `time auto on` sends your Wi-Fi networks or IP address to a location web service; the plan says so first.

### `bxcachy toggle` {#bxcachy-toggle}

Quick switches. Today: stay awake (Noctalia caffeine).

```text
bxcachy toggle stay-awake [on|off]
```

```bash
bxcachy toggle stay-awake
```

### `bxcachy nightshift` {#bxcachy-nightshift}

Night light: on, off, toggle, status (sunset to sunrise from your time zone).

```text
bxcachy nightshift [on|off|toggle|status] [--location=LAT,LON] [--json]
```

```bash
bxcachy nightshift toggle
bxcachy nightshift on --location=40.4,-3.7
```

### `bxcachy notify` {#bxcachy-notify}

Notifications through Noctalia: do not disturb, snooze, history, clear.

```text
bxcachy notify dnd on|off|toggle|status | snooze [30m|2h|90s|off] | clear [--history] [--json]
```

```bash
bxcachy notify dnd toggle
bxcachy notify snooze 2h
bxcachy notify clear --history
```

## System and security

Updates, snapshots, DNS, kernels, keys and secrets.

### `bxcachy system` {#bxcachy-system}

Update the system (a snapshot first), lock, suspend, log out, reboot, shut down.

```text
bxcachy system update [--yes] | lock | suspend | logout|reboot|shutdown [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy system update --yes
bxcachy system reboot --yes
```

> lock and suspend act at once; logout, reboot and shutdown need --yes (the menu asks first).

### `bxcachy security` {#bxcachy-security}

Fingerprint and security key for sudo, SSH server, passwordless sudo, with guards.

```text
bxcachy security status [--json]
bxcachy security fingerprint on|off|enroll [--yes]
bxcachy security fido2 on|off|register [--yes]
bxcachy security ssh-server on|off [--yes]
bxcachy security passwordless-sudo on|off [--yes]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy security status
bxcachy security fingerprint on --dry-run
bxcachy security passwordless-sudo on --yes
```

> Only /etc/pam.d/sudo is ever changed, with a `sufficient` line and a backup; sudoers is checked with visudo first. `--dry-run` prints the exact line.

### `bxcachy dns` {#bxcachy-dns}

DNS servers of the active connections: Cloudflare, Google, Quad9, your own, or back to DHCP.

```text
bxcachy dns [cloudflare|google|quad9|dhcp|custom IP[,IP...]] [--yes] [--dry-run]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy dns
bxcachy dns cloudflare --yes
bxcachy dns custom 9.9.9.10 --yes
```

### `bxcachy kernel` {#bxcachy-kernel}

List, install and remove kernels. Never edits the bootloader.

```text
bxcachy kernel list | install NAME | remove NAME [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy kernel list
bxcachy kernel install linux-cachyos-lts --yes
```

### `bxcachy ssh` {#bxcachy-ssh}

Create an SSH key (ed25519; an existing one is kept).

```text
bxcachy ssh key [--email=ADDRESS] [--yes] [--dry-run] [--json]
```

```bash
bxcachy ssh key --email=me@example.com --yes
```

### `bxcachy secrets` {#bxcachy-secrets}

API keys and tokens in the system keyring, loaded per command, exported encrypted.

```text
bxcachy secrets status | setup [--keyring=kwallet|gnome-keyring|none] [--yes] | list [--type=ai|other] | set NAME [--from-file=F] [--type=ai|other] [--provider=ID] | get NAME [--show] | unset NAME --yes | apply [--yes] | global on NAME --yes|off NAME|show | unlock | lock | export FILE [--plain] [--force] --yes | import FILE [--overwrite] --yes | env [NAMES...] | run [NAMES...] [--strict] -- COMMAND [ARGS...] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy secrets set ANTHROPIC_API_KEY
bxcachy secrets run ANTHROPIC_API_KEY -- claude
bxcachy secrets list
```

### `bxcachy vpn` {#bxcachy-vpn}

VPN post-install steps for NordVPN.

```text
bxcachy vpn nordvpn setup [--yes] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy vpn nordvpn setup --yes
```

### `bxcachy cloud` {#bxcachy-cloud}

Cloud storage with rclone: remotes, mounts as systemd user units.

```text
bxcachy cloud remotes | configure | mount NAME [--path=DIR] [--yes] | unmount NAME [--yes] | status [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy cloud remotes
bxcachy cloud mount gdrive --path=~/Drive --yes
```

### `bxcachy settings` {#bxcachy-settings}

Export and import your BxCachy settings as one archive.

```text
bxcachy settings export FILE.tar.gz [--force] | import FILE.tar.gz [--yes] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy settings export my-settings.tar.gz
bxcachy settings import my-settings.tar.gz --yes
```

### `bxcachy dotfiles` {#bxcachy-dotfiles}

Apply your dotfiles repo with chezmoi, yadm, stow or plain links, never overwriting unasked, with undo.

```text
bxcachy dotfiles plan REPO [--method=chezmoi|yadm|stow|links] | apply REPO [--method=M] [--overwrite] [--yes] [--dry-run] | status | undo [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy dotfiles plan https://github.com/me/dotfiles
bxcachy dotfiles apply https://github.com/me/dotfiles --yes
```

### `bxcachy nas` {#bxcachy-nas}

Your NAS boxes: find them, save their details, list shares, mount them (also automatically), test them, mirror folders to them, use one as a backup target.

```text
bxcachy nas setup [--yes]
bxcachy nas discover [--json]
bxcachy nas add NAME --host=H [--protocol=smb|nfs] [--user=U] [--vers=3.1.1] [--ask-password | --password-file=F]
bxcachy nas list | show NAME | remove NAME [--yes]
bxcachy nas shares NAME
bxcachy nas mount|unmount NAME SHARE [--yes]
bxcachy nas auto on|off NAME SHARE [--yes]
bxcachy nas test NAME [SHARE]
bxcachy nas sync NAME SRC --to=SHARE[/PATH] [--delete] [--yes]
bxcachy nas use NAME SHARE [--path=bxcachy-backup]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy nas discover
bxcachy nas add synology --host=ds920.local --user=me --ask-password
bxcachy nas shares synology
bxcachy nas mount synology backups --yes
bxcachy nas auto on synology backups --yes
bxcachy nas use synology backups
```

> SMB mounts are made by root, so the password is also kept in /etc/bxcachy/nas/NAME.cred (mode 600); the plan says so. The SMB version is negotiated unless you give --vers. Nothing on the NAS is deleted unless you add --delete to a sync.

### `bxcachy backup` {#bxcachy-backup}

Backups of your BxCachy setup, of the system and of your files, and a way to move them around.

```text
bxcachy backup config now [--reason=TEXT] [--with-secrets]
bxcachy backup config list | show ID | diff ID
bxcachy backup config restore ID [--only=PATH] [--packages] [--yes] [--dry-run]
bxcachy backup config auto on|off|status | prune [--keep=N] [--yes]
bxcachy backup config paths | add PATH | remove PATH
bxcachy backup snapshots status | list [--json]
bxcachy backup snapshots setup [--home] [--yes]
bxcachy backup snapshots create [--description=TEXT] [--yes]
bxcachy backup snapshots delete ID | changes ID | restore ID PATH [--yes]
bxcachy backup data status | targets [--json]
bxcachy backup data target add NAME --type=local|sftp|rest|s3|b2|azure|gs|rclone [--path=P --host=H --user=U --url=U --bucket=B --endpoint=URL --region=R --container=C --project=ID --credentials=FILE --remote=R] [--ask-keys | --keys-file=F]
bxcachy backup data target remove NAME [--yes]
bxcachy backup data init NAME [--yes]
bxcachy backup data run [--target=NAME] [--yes]
bxcachy backup data list [--target=NAME] | files ID [PATH] | restore ID --to=DIR [--include=PATH] [--yes]
bxcachy backup data verify [--deep] | forget [--yes] | retention [--daily=N --weekly=N --monthly=N]
bxcachy backup data schedule hourly|daily|off|status [--yes]
bxcachy backup data include|exclude add|remove PATH_OR_PATTERN
bxcachy backup send ID|all --to=TARGET [--from=TARGET] [--yes]
bxcachy backup export data ID --to=FILE.tar|FILE.zip [--path=/PATH] [--target=NAME] [--yes]
bxcachy backup export config ID --to=FILE.tar.gz [--yes]
bxcachy backup timeline [--local] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy backup config now
bxcachy backup config list
bxcachy backup config diff 20261113T153000
bxcachy backup config restore 20261113T153000 --dry-run
bxcachy backup config restore 20261113T153000 --only=.config/hypr --yes
bxcachy backup snapshots setup --yes
bxcachy backup snapshots list
bxcachy backup snapshots restore 12 /home/me/projects/app --dry-run
bxcachy backup data target add do --type=s3 --endpoint=https://nyc3.digitaloceanspaces.com --bucket=mybackups --ask-keys
bxcachy backup data init do --yes
bxcachy backup data run --yes
bxcachy backup data schedule daily --yes
bxcachy backup data restore latest --to=~/restored --yes
bxcachy backup send latest --from=usb --to=do --yes
bxcachy backup export data latest --to=~/projects.zip --path=/home/me/Projects --yes
bxcachy backup export config 20261113T153000 --to=~/my-setup.tar.gz --yes
bxcachy backup timeline --local
```

> A config snapshot is taken by itself before update, system update, init, reinstall and refresh (turn it off with backup config auto off). Secrets and SSH keys are never in it unless you add --with-secrets, which stores your secrets export, encrypted with a passphrase you type.

### `bxcachy timemachine` {#bxcachy-timemachine}

BxTimeMachine: every backup of your system, setup and files on one timeline, with browse, restore, export and send.

```text
bxcachy timemachine [--demo] [--local]
```

```bash
bxcachy timemachine
bxcachy timemachine --local
bxcachy timemachine --demo
```

> It needs a terminal (also available as bxtimemachine). Restore, export, send and back up now show the plan first and change nothing until you press y. --local skips the network targets so it opens at once; --demo shows made-up data and runs nothing.

### `bxcachy java` {#bxcachy-java}

Your Java homes: list them, install a JDK (through SDKMAN when you have it), choose the default for new shells.

```text
bxcachy java list | available | install MAJOR|IDENTIFIER [--yes] [--dry-run] | default ID|MAJOR [--yes] | default --unset [--yes] | remove ID [--yes] | env [ID|MAJOR] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy java list
bxcachy java install 21 --yes
bxcachy java default 21 --yes
bxcachy java env 17
```

> Homes come from SDKMAN, BxCachy's own Temurin installs (~/.local/share/bxcachy/java) and /usr/lib/jvm. With SDKMAN installed (bxcachy sdk setup) installs and removals go through it: a major like 21 picks the newest Temurin, an identifier like 21.0.13.0+9-tem installs exactly that. Without it a Temurin JDK is downloaded straight from Adoptium. The system's own JDKs are never deleted. The default is written to java.sh and java.fish, which the shell starters source, so run bxcachy refresh shell once on an existing setup.

### `bxcachy sdk` {#bxcachy-sdk}

Java, Maven and Gradle through SDKMAN: install, switch, remove.

```text
bxcachy sdk status | setup [--yes] | list java|maven|gradle | available java|maven|gradle | install CANDIDATE VERSION [--yes] | default CANDIDATE VERSION [--yes] | remove CANDIDATE VERSION [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy sdk setup --yes
bxcachy sdk available maven
bxcachy sdk install maven 3.9.9 --yes
bxcachy sdk default gradle 8.10.2 --yes
```

> setup installs SDKMAN into ~/.sdkman without touching your shell files. Maven and Gradle reach your shells through ~/.config/bxcachy/sdk.sh and sdk.fish, which the shell starters source (bxcachy refresh shell on an existing setup). Version lists come from api.sdkman.io.

### `bxcachy tui` {#bxcachy-tui}

Control Center: every BxCachy screen in one terminal, starting with the Dashboard.

```text
bxcachy tui [PAGE] [--demo] [--json]
```

```bash
bxcachy tui
bxcachy tui dashboard --json
bxcachy tui --demo
```

> It needs a terminal. The sidebar lists the pages; Tab switches page, q leaves. The Dashboard shows what needs attention, system meters, what runs and your backups, and Enter on a warning shows the plan of the fix before anything changes. --json prints a page's data without a terminal; --demo shows made-up data and runs nothing.

### `bxcachy bxtimemachine` {#bxcachy-bxtimemachine}

The same as timemachine: BxTimeMachine, your backups through time.

```text
bxcachy bxtimemachine [--demo] [--local]
```

```bash
bxcachy bxtimemachine
```

## Develop

BoxLang, editors, databases, containers, virtual machines and AI agents.

### `bxcachy boxlang` {#bxcachy-boxlang}

BoxLang status, modules (ForgeBox), the VS Code extension, links.

```text
bxcachy boxlang status | use VERSION | matchbox use VERSION | modules list|search TEXT|install SLUG...|installed|outdated|update | vscode | links | welcome [--json]
```

```bash
bxcachy boxlang status
bxcachy boxlang modules list
bxcachy boxlang use 1.8.0
```

### `bxcachy editor` {#bxcachy-editor}

Neovim with LazyVim, the BoxLang plugin and themes that follow the BxCachy theme.

```text
bxcachy editor lazyvim [--yes] | boxlang [--yes] | status | refresh [--force] [--yes] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy editor lazyvim --yes
bxcachy editor status
```

### `bxcachy db` {#bxcachy-db}

Databases as containers (Podman or Docker): PostgreSQL, MySQL, Redis, MongoDB, Couchbase, vector stores.

```text
bxcachy db engines | list | start ENGINE [--name N] [--port P] [--password-file FILE | --ask-password] [--yes] [--dry-run] | stop|status|logs ENGINE [--name N] | remove ENGINE [--name N] [--keep-data] --yes | info ENGINE [--name N] [--show-password] | engine [podman|docker] | menu [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy db engines
bxcachy db start postgres --yes
bxcachy db info postgres
```

### `bxcachy containers` {#bxcachy-containers}

Podman helpers: doctor, rootless socket, docker compatibility wrappers.

```text
bxcachy containers doctor | socket enable [--yes] | docker-compat [--yes] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy containers doctor
```

### `bxcachy vm` {#bxcachy-vm}

Virtual machines in containers: Windows (dockur) and Linux desktops (webtop), with sizes and status.

```text
bxcachy vm list | status [NAME] | size [NAME] | info NAME [--show-password] | doctor | versions linux|windows | create windows [NAME] [--version=V] [--ram=8G] [--cpus=N] [--disk=64G] [--share=PATH|none] | create linux NAME [--tag=ubuntu-xfce] [--cpus=N] [--memory=4G] [--share=PATH|none] [--gpu=none|auto|intel|amd|nvidia] | start|stop|logs NAME | open NAME [--web] [--fullscreen] | remove NAME [--keep-data] [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy vm doctor
bxcachy vm create linux dev --tag=ubuntu-xfce --yes
bxcachy vm open dev
```

### `bxcachy ai` {#bxcachy-ai}

AI agents: list, default, launch, tmux sessions, local models, the pull-down AI shell.

```text
bxcachy ai session start [ID] [--name=N] [--dir=PATH] [--dry-run] | list | attach NAME | stop NAME --yes [--json]
bxcachy ai models list | ps | pull NAME | rm NAME --yes | status | enable [--yes] [--json]
bxcachy ai list | default [ID] [--yes] | launch [ID] [--dry-run] | session ... | models ... | shell [toggle|status] [--backend=hyprland|yakuake] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy ai list
bxcachy ai launch
bxcachy ai models pull llama3.2
bxcachy ai session start --name=work
```

### `bxcachy skills` {#bxcachy-skills}

Agent skills for BoxLang and BxCachy: install, update, remove.

```text
bxcachy skills list [--tag=T] | search TEXT | show OWNER/REPO/SLUG | install [bxcachy|boxlang|matchbox|OWNER/REPO/SLUG]... [--yes] | installed | update [--yes] | remove NAME [--yes] | status | link [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxcachy skills install --yes
bxcachy skills list
bxcachy skills status
```

## Everyday tools

Screenshots, clipboard, windows, dictation and hardware helpers.

### `bxcachy screenshot` {#bxcachy-screenshot}

Screenshots: screen, region, window, OCR text, QR codes, or a menu.

```text
bxcachy screenshot screen|region|window [--edit] | ocr | qr | menu [--dry-run] [--json]
```

```bash
bxcachy screenshot region
bxcachy screenshot screen --edit
bxcachy screenshot ocr
```

### `bxcachy qr` {#bxcachy-qr}

Make a QR code from text (printed in the terminal, or saved with --out).

```text
bxcachy qr TEXT [--out=FILE.png] [--json]
```

```bash
bxcachy qr https://boxlang.io
bxcachy qr 'wifi text' --out=wifi.png
```

### `bxcachy record` {#bxcachy-record}

Screen recording: start, stop, toggle.

```text
bxcachy record [toggle|start|stop|status] [--region] [--dry-run] [--json]
```

```bash
bxcachy record toggle
bxcachy record start --region
```

### `bxcachy clipboard` {#bxcachy-clipboard}

Clipboard history (cliphist): pick, list, clear, setup.

```text
bxcachy clipboard pick | clear [--yes] | status [--json]
```

```bash
bxcachy clipboard pick
bxcachy clipboard status
```

### `bxcachy emoji` {#bxcachy-emoji}

The emoji picker (rofimoji).

```text
bxcachy emoji
```

```bash
bxcachy emoji
```

### `bxcachy forcequit` {#bxcachy-forcequit}

Pick a window or process and force quit it.

```text
bxcachy forcequit
```

```bash
bxcachy forcequit
```

### `bxcachy window` {#bxcachy-window}

Minimize and restore windows.

```text
bxcachy window minimize|restore
```

```bash
bxcachy window minimize
bxcachy window restore
```

### `bxcachy overview` {#bxcachy-overview}

The workspace and window overview.

```text
bxcachy overview [setup]
```

```bash
bxcachy overview
```

### `bxcachy quicklook` {#bxcachy-quicklook}

Quick Look for files (Kiview): preview with a key.

```text
bxcachy quicklook [PATH] [--dry-run] [--json]
```

```bash
bxcachy quicklook photo.jpg
```

### `bxcachy dolphin` {#bxcachy-dolphin}

Dolphin diagnostics: why it is slow or missing features.

```text
bxcachy dolphin doctor [--fix] [--json]
```

```bash
bxcachy dolphin doctor
bxcachy dolphin doctor --fix
```

### `bxcachy dictation` {#bxcachy-dictation}

Dictation with Superwhisper or Voxtype: setup and toggle.

```text
bxcachy dictation setup [superwhisper|voxtype] [--yes] [--dry-run] | status | key [ENGINE] [--json]
```

```bash
bxcachy dictation setup voxtype --yes
bxcachy dictation status
```

### `bxcachy strata` {#bxcachy-strata}

Strata, the file manager: its integrations.

```text
bxcachy strata integrations [--dry-run] [--json]
```

```bash
bxcachy strata integrations --dry-run
```

### `bxcachy gpu` {#bxcachy-gpu}

GPU check: driver, rendering, NVIDIA specifics.

```text
bxcachy gpu doctor [--json]
```

```bash
bxcachy gpu doctor
```

### `bxcachy input` {#bxcachy-input}

Input devices: doctor, trackpad gestures.

```text
bxcachy input doctor | gestures [--yes] [--dry-run] [--json]
```

```bash
bxcachy input doctor
```

### `bxcachy airplay` {#bxcachy-airplay}

AirPlay receiver: on, off, status.

```text
bxcachy airplay on|off|status [--json]
```

```bash
bxcachy airplay on
```

---
title: Command reference
order: 1
summary: Every bxrig command with its usage, examples and exit codes.
---

# Command reference

Every command is `bxrig NAME ...`. This page is generated from `docs/reference/cli.json`; the same data answers `bxrig help` and `bxrig help NAME` in the terminal. The [command contract](../architecture/COMMAND-CONTRACT.md) has the details behind each one.

## How commands behave

| Flag | What it does |
|---|---|
| `--json` | Print one JSON object instead of text (see below). Every command takes it. |
| `--yes` | Apply a change that installs packages or edits system files. Without it you get the plan and exit code 2. |
| `--dry-run` | Print the plan or the exact commands and exit 0. Nothing is changed. |
| `--force` | Where it exists: replace a file BxRig would otherwise keep because you edited it. |

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

**Start here**: [`init`](#bxrig-init), [`refresh`](#bxrig-refresh), [`reinstall`](#bxrig-reinstall), [`wizard`](#bxrig-wizard), [`status`](#bxrig-status), [`doctor`](#bxrig-doctor), [`update`](#bxrig-update), [`version`](#bxrig-version), [`menu`](#bxrig-menu), [`apps`](#bxrig-apps), [`help`](#bxrig-help)

**Install and remove**: [`install`](#bxrig-install), [`remove`](#bxrig-remove), [`pkg`](#bxrig-pkg), [`catalog`](#bxrig-catalog), [`plan`](#bxrig-plan), [`install-plan`](#bxrig-install-plan), [`optional-plan`](#bxrig-optional-plan), [`profile-plan`](#bxrig-profile-plan), [`profile-install-plan`](#bxrig-profile-install-plan), [`profile-install`](#bxrig-profile-install), [`optional-install`](#bxrig-optional-install), [`profile-list`](#bxrig-profile-list), [`optional-list`](#bxrig-optional-list), [`desktop-list`](#bxrig-desktop-list), [`tui-list`](#bxrig-tui-list), [`web-list`](#bxrig-web-list), [`package-status`](#bxrig-package-status), [`package-source`](#bxrig-package-source), [`dev-plan`](#bxrig-dev-plan), [`prerequisites`](#bxrig-prerequisites), [`apps-doctor`](#bxrig-apps-doctor), [`web`](#bxrig-web), [`toolchain`](#bxrig-toolchain)

**Desktop setup**: [`setup`](#bxrig-setup), [`session`](#bxrig-session), [`tiling`](#bxrig-tiling), [`plasma`](#bxrig-plasma), [`keys`](#bxrig-keys), [`runner`](#bxrig-runner), [`default`](#bxrig-default), [`layout`](#bxrig-layout), [`assets`](#bxrig-assets), [`launchers`](#bxrig-launchers), [`config`](#bxrig-config)

**Look and feel**: [`theme`](#bxrig-theme), [`appearance`](#bxrig-appearance), [`display`](#bxrig-display), [`power`](#bxrig-power), [`time`](#bxrig-time), [`toggle`](#bxrig-toggle), [`nightshift`](#bxrig-nightshift), [`notify`](#bxrig-notify)

**System and security**: [`system`](#bxrig-system), [`security`](#bxrig-security), [`dns`](#bxrig-dns), [`kernel`](#bxrig-kernel), [`ssh`](#bxrig-ssh), [`secrets`](#bxrig-secrets), [`vpn`](#bxrig-vpn), [`cloud`](#bxrig-cloud), [`settings`](#bxrig-settings), [`dotfiles`](#bxrig-dotfiles), [`nas`](#bxrig-nas), [`backup`](#bxrig-backup), [`timemachine`](#bxrig-timemachine), [`java`](#bxrig-java), [`sdk`](#bxrig-sdk), [`mail`](#bxrig-mail), [`tui`](#bxrig-tui), [`bxtimemachine`](#bxrig-bxtimemachine)

**Develop**: [`boxlang`](#bxrig-boxlang), [`editor`](#bxrig-editor), [`db`](#bxrig-db), [`containers`](#bxrig-containers), [`vm`](#bxrig-vm), [`ai`](#bxrig-ai), [`skills`](#bxrig-skills)

**Everyday tools**: [`screenshot`](#bxrig-screenshot), [`qr`](#bxrig-qr), [`record`](#bxrig-record), [`clipboard`](#bxrig-clipboard), [`emoji`](#bxrig-emoji), [`forcequit`](#bxrig-forcequit), [`window`](#bxrig-window), [`overview`](#bxrig-overview), [`quicklook`](#bxrig-quicklook), [`dolphin`](#bxrig-dolphin), [`dictation`](#bxrig-dictation), [`strata`](#bxrig-strata), [`gpu`](#bxrig-gpu), [`input`](#bxrig-input), [`airplay`](#bxrig-airplay)

## Start here

Set up the machine, see where it stands, keep it current.

### `bxrig init` {#bxrig-init}

The setup wizard: asks the questions, shows a review, then runs the matching commands.

```text
bxrig init [--from=FILE] [--fresh | --rerun] | init --answers=FILE [--yes] [--dry-run] [--json] | init --print-answers [--from-system] [--json] | init --export=FILE [--force]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig init
bxrig init --answers=answers.json --yes
bxrig init --print-answers --from-system --json
```

### `bxrig refresh` {#bxrig-refresh}

Put a managed config back to what BxRig ships, with a backup first and without installing anything.

```text
bxrig refresh hyprland|noctalia|terminals|shell|nvim|theme|all [--starter] [--force] [--yes] [--dry-run] [--json]
bxrig refresh list [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig refresh list
bxrig refresh terminals --dry-run
bxrig refresh hyprland --yes
bxrig refresh shell --yes --force
```

> A file you edited is kept and reported; --force overwrites it after a backup (see config history and config restore). --starter also rewrites the starter hyprland.lua or Noctalia config.toml, which are yours.

### `bxrig reinstall` {#bxrig-reinstall}

Run the setup wizard again from your saved answers (the same as init --rerun).

```text
bxrig reinstall [--yes] [--dry-run] [--json]
```

```bash
bxrig reinstall
```

> This is the way to install packages again. refresh only puts config files back.

### `bxrig wizard` {#bxrig-wizard}

Wizard pieces for scripts: render the demo screens or a pages file.

```text
bxrig wizard --demo [--out=FILE] | --pages=FILE [--out=FILE] [--answers=FILE]
```

```bash
bxrig wizard --demo
```

### `bxrig status` {#bxrig-status}

What is installed and configured on this machine, compared with what BxRig would do.

```text
bxrig status [--json]
```

```bash
bxrig status
bxrig status --json
```

### `bxrig doctor` {#bxrig-doctor}

Checks the machine (Arch or CachyOS, pacman, sudo, disk) and reports problems.

```text
bxrig doctor [--json]
```

```bash
bxrig doctor
```

### `bxrig update` {#bxrig-update}

Check for a BxRig update, apply it, pick a channel, turn the daily notification on or off.

```text
bxrig update check [--notify] | apply [--yes] | channel [stable|beta] | notifications on|off|status [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig update check
bxrig update apply --yes
bxrig update channel beta
bxrig update notifications on
```

> Exit 10 from `update check` means an update is available.

### `bxrig version` {#bxrig-version}

The BxRig version and build.

```text
bxrig version [--json]
```

```bash
bxrig version
```

### `bxrig menu` {#bxrig-menu}

The control center: every command as a menu on your launcher (Rofi, Walker, Wofi, Fuzzel or Vicinae).

```text
bxrig menu | menu items [--json] | menu search TEXT [--json]
```

```bash
bxrig menu
bxrig menu search 'time zone'
```

> Bind it to a key; the first entry, Search, lists every entry as one flat list.

### `bxrig apps` {#bxrig-apps}

Your installed catalog apps, as a list or a launcher grid.

```text
bxrig apps | apps list [--json]
```

```bash
bxrig apps list
```

### `bxrig help` {#bxrig-help}

This list, or the usage of one command.

```text
bxrig help [COMMAND]
```

```bash
bxrig help
bxrig help appearance
```

## Install and remove

Apps from the catalog, any package from the repositories or the AUR, and the reverse.

### `bxrig install` {#bxrig-install}

Install catalog apps by id (or a whole group or profile).

```text
bxrig install [NAME] [--optional] [--shell=hyprland|plasma|all] [--json] [--yes] [--dry-run]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig install --dry-run
bxrig install --yes
```

> With no name it installs the default set; without --yes it prints the plan and changes nothing.

### `bxrig remove` {#bxrig-remove}

Uninstall catalog apps (their packages or web launchers).

```text
bxrig remove ID_OR_PACKAGE... [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig remove lazygit --yes
```

> Protected packages (the base system, the kernel, bxrig itself) are refused.

### `bxrig pkg` {#bxrig-pkg}

Search, inspect, install and remove any package from the repositories and the AUR.

```text
bxrig pkg search TEXT [--source=all|repo|aur] [--limit=N] | info NAME | installed [--explicit] | install NAME... [--aur] [--yes] [--dry-run] | remove NAME... [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig pkg search ripgrep
bxrig pkg install ripgrep --yes
bxrig pkg remove htop --yes
```

### `bxrig catalog` {#bxrig-catalog}

Browse the app catalog.

```text
bxrig catalog list [--group=G] [--category=C] [--tier=default|optional] [--kind=K] [--source=S] [--json] | show ID | groups | check | version
```

```bash
bxrig catalog groups
bxrig catalog list --group=ai --tier=default
bxrig catalog show lazygit
```

### `bxrig plan` {#bxrig-plan}

Show what installing would do, without doing it.

```text
bxrig plan [NAME] [--optional] [--shell=hyprland|plasma|all] [--json]
```

```bash
bxrig plan
bxrig plan --shell=hyprland --json
```

### `bxrig install-plan` {#bxrig-install-plan}

The install plan for the selection (same as plan).

```text
bxrig install-plan [NAME] [--optional] [--shell=hyprland|plasma|all] [--json]
```

### `bxrig optional-plan` {#bxrig-optional-plan}

The plan for the optional apps.

```text
bxrig optional-plan [--shell=hyprland|plasma|all] [--json]
```

### `bxrig profile-plan` {#bxrig-profile-plan}

The plan for one profile.

```text
bxrig profile-plan NAME [--optional] [--shell=hyprland|plasma|all] [--json]
```

```bash
bxrig profile-plan jvm
```

### `bxrig profile-install-plan` {#bxrig-profile-install-plan}

The install steps for one profile.

```text
bxrig profile-install-plan NAME [--optional] [--shell=hyprland|plasma|all] [--json]
```

### `bxrig profile-install` {#bxrig-profile-install}

Install a profile (jvm, containers, terminal, editors, ...).

```text
bxrig profile-install NAME [--optional] [--shell=hyprland|plasma|all] [--json] [--yes] [--dry-run]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig profile-install terminal --yes
```

### `bxrig optional-install` {#bxrig-optional-install}

Install the optional apps of the catalog.

```text
bxrig optional-install [--shell=hyprland|plasma|all] [--json] [--yes] [--dry-run]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

### `bxrig profile-list` {#bxrig-profile-list}

List the profiles.

```text
bxrig profile-list [--json]
```

### `bxrig optional-list` {#bxrig-optional-list}

List the optional apps.

```text
bxrig optional-list [--json]
```

### `bxrig desktop-list` {#bxrig-desktop-list}

List the desktop apps in the catalog.

```text
bxrig desktop-list [--json]
```

### `bxrig tui-list` {#bxrig-tui-list}

List the terminal apps in the catalog.

```text
bxrig tui-list [--json]
```

### `bxrig web-list` {#bxrig-web-list}

List the web apps in the catalog.

```text
bxrig web-list [--json]
```

### `bxrig package-status` {#bxrig-package-status}

Whether a catalog app is installed.

```text
bxrig package-status ID
```

```bash
bxrig package-status lazygit
```

### `bxrig package-source` {#bxrig-package-source}

Where a catalog app comes from (pacman, AUR, PKGBUILD, web).

```text
bxrig package-source ID
```

```bash
bxrig package-source lazygit
```

### `bxrig dev-plan` {#bxrig-dev-plan}

What the developer toolchain install would use: Java 21, Maven, Gradle, BVM, MVM.

```text
bxrig dev-plan
```

### `bxrig prerequisites` {#bxrig-prerequisites}

What BxRig needs on the machine before anything else.

```text
bxrig prerequisites [--json]
```

### `bxrig apps-doctor` {#bxrig-apps-doctor}

Checks the catalog apps for missing or broken installs.

```text
bxrig apps-doctor [--json]
```

### `bxrig web` {#bxrig-web}

Web apps: create one from a URL, install a set (Google, Microsoft, Apple, BoxLang).

```text
bxrig web add [NAME URL] [--browser=brave|chromium|google-chrome|edge|firefox] [--yes] | list | rm NAME [--yes] | install google|microsoft|apple|boxlang|all [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig web add Notes https://notes.example.com --yes
bxrig web install google --yes
bxrig web rm Notes --yes
```

### `bxrig toolchain` {#bxrig-toolchain}

Language toolchains outside the always-installed BoxLang one (Node via nvm, Rust, Python, Go, PHP).

```text
bxrig toolchain node [--yes] [--dry-run] [--json]   (Bun and Deno: bxrig install bun deno)
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig toolchain node --yes
```

## Desktop setup

Hyprland with Noctalia, or KDE Plasma beside it: the session, the keys, the defaults.

### `bxrig setup` {#bxrig-setup}

Set up a desktop: Hyprland with Noctalia, Plasma with HyprKwin tiling, terminals, keyboards, status.

```text
bxrig setup plasma [--keys | --undo-keys] | hyprland [--terminal=ghostty|kitty|alacritty|foot|konsole] [--layout=dwindle|master|scrolling|floating] [--workspaces=N] [--natural-scroll] [--layouts=us-intl,es] [--theme=dark|light|auto] [--wallpaper=box|grid|aurora|minimal] | terminal [--default=ghostty] [--also=a,b] | shell [--shell=zsh|fish|bash] | keyboard [--layouts=us-intl,es] | xremap [--build=hypr|kde] | undo plasma|hyprland|xremap | status [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig setup hyprland --yes
bxrig setup terminal --default=ghostty --also=kitty --yes
```

### `bxrig session` {#bxrig-session}

Which desktop SDDM starts: Hyprland or Plasma.

```text
bxrig session show | set hyprland|plasma [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig session show
```

### `bxrig tiling` {#bxrig-tiling}

Tiling inside Plasma (HyprKwin): on, off, status, layouts.

```text
bxrig tiling on|off|status | layout [dwindle|master|monocle|scrolling|stage] [--json]
```

```bash
bxrig tiling on
bxrig tiling layout dwindle
```

### `bxrig plasma` {#bxrig-plasma}

Plasma extras: panel layouts (apply, undo, status) and the islands preset.

```text
bxrig plasma panels apply [--agenda] [--without-weather] [--desktops=N] [--preset=NAME] | undo | status [--yes] [--dry-run] [--json]  |  plasma desktops N [--yes]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig plasma panels apply --preset=islands --yes
bxrig plasma desktops 4 --yes
```

### `bxrig keys` {#bxrig-keys}

The shortcut table: show, check conflicts, apply to Hyprland and Plasma, Mac-style keys.

```text
bxrig keys show | mac [on|off|status] [--yes] | set ID KEYS [--yes] [--force] | reset ID [--yes] | conflicts | render xremap|hyprland|plasma | check | apply [--yes] [--dry-run] [--force] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig keys show
bxrig keys set emoji Super+Ctrl+E --yes
bxrig keys mac on --yes
bxrig keys conflicts
```

### `bxrig runner` {#bxrig-runner}

Which launcher and which menu program BxRig uses (Rofi, Walker, Wofi, Fuzzel, Vicinae).

```text
bxrig runner list | show | doctor | launch | select JSON_ENTRIES [--prompt=TEXT] | set PROVIDER | menu-set PROVIDER | launcher-command PROVIDER JSON_ARGV | menu-command PROVIDER JSON_ARGV [--json]
```

```bash
bxrig runner list
bxrig runner set rofi
bxrig runner doctor
```

### `bxrig default` {#bxrig-default}

Default apps: browser, terminal, file manager.

```text
bxrig default show | browser ID | terminal ID | filemanager ID [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig default show
bxrig default browser brave --yes
```

### `bxrig layout` {#bxrig-layout}

Window layout at runtime: tile or float (toggle).

```text
bxrig layout [toggle|float|tile|status] [--dry-run] [--json]
```

```bash
bxrig layout toggle
```

### `bxrig assets` {#bxrig-assets}

Brand assets (logo, icon, wallpapers): list, or install them.

```text
bxrig assets list | install [--yes] [--dry-run] [--json]
```

```bash
bxrig assets list
```

### `bxrig launchers` {#bxrig-launchers}

Application-menu entries for the Control Center pages (opt-in): on, off, status.

```text
bxrig launchers on|off|status [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig launchers status
bxrig launchers on --dry-run
bxrig launchers on --yes
bxrig launchers off --yes
```

> `on` writes one entry per page to ~/.local/share/applications (BxRig Databases, ...), each opening `bxrig tui PAGE` in your terminal, and the BxRig icon to ~/.local/share/icons/hicolor/256x256/apps/bxrig.png. An entry you edited is kept, never overwritten or removed. `off` (or `bxrig remove launchers`) takes them out again. Nothing is added unless you ask.

### `bxrig config` {#bxrig-config}

The managed config files: list, diff, apply, restore a backup, history. A file you edited is never overwritten.

```text
bxrig config list|diff NAME|apply NAME|restore NAME ID|history [NAME] [--yes] [--dry-run] [--force] [--json]
bxrig config restore NAME ID --yes
```

```bash
bxrig config list
bxrig config diff hypr/bxrig.lua
bxrig config history
```

> BxRig never overwrites a file you edited; `config status` shows which ones are yours.

## Look and feel

Themes, fonts, bar, dock, windows, monitors and power.

### `bxrig theme` {#bxrig-theme}

Themes: 15 bundled (10 from Omarchy, 5 BxRig), set one, light or dark, install from git.

```text
bxrig theme list | show NAME | set NAME [--mode=theme|dark|light|auto] [--keep-wallpaper] | random | next | mode theme|dark|light|auto | install GIT_URL [--name=N] [--force] | import PATH [--name=N] [--force] | remove NAME | vscode [--yes] [--dry-run] | status [--dry-run] [--json]
```

```bash
bxrig theme list
bxrig theme set tokyo-night --mode=dark
bxrig theme install https://github.com/user/theme --name=mine
bxrig theme mode auto
bxrig theme vscode --yes
```

> A theme colours the bar, terminals, btop, Neovim, GTK and Qt apps, tmux, fzf, launchers and (on Plasma) the colour scheme. VS Code is opt-in.

### `bxrig appearance` {#bxrig-appearance}

Bar, dock, windows, animations, layout, fonts and backgrounds, one setting at a time.

```text
bxrig appearance status|apply [--json]
bxrig appearance bar show|hide|toggle | position top|bottom|left|right | style opaque|glassy|clear | clock ID | battery on|off
bxrig appearance dock show|hide|toggle | mode always|autohide|off | position bottom|left|right
bxrig appearance windows gaps on|off | corners theme|rounded|sharp | opacity opaque|glassy | one-window-ratio on|off
bxrig appearance animations on|off
bxrig appearance layout dwindle|scrolling|floating
bxrig appearance font list | ID | install ID [--yes]
bxrig appearance background list | set NAME_OR_PATH | next | random
```

```bash
bxrig appearance bar position bottom
bxrig appearance windows gaps off
bxrig appearance font install cascadia --yes
bxrig appearance background random
```

> Settings act at once (no --yes); --dry-run shows the commands. What you choose is remembered, and `appearance apply` pushes it again.

### `bxrig display` {#bxrig-display}

Monitors: scale, rotation, mode, position, mirroring the laptop panel, turning it off, brightness.

```text
bxrig display list|status [--json]
bxrig display scale NAME auto|0.5..4
bxrig display rotate NAME 0|90|180|270
bxrig display mode NAME preferred|WxH[@R]
bxrig display position NAME auto|XxY
bxrig display mirror on|off
bxrig display laptop on|off
bxrig display brightness up|down|set N
bxrig display apply | reset
```

```bash
bxrig display list
bxrig display scale DP-2 1.5
bxrig display mirror on
bxrig display brightness set 40
```

> On Hyprland it writes theme/monitors.lua and reloads; on Plasma it uses kscreen-doctor.

### `bxrig power` {#bxrig-power}

Laptop power: profile, lid action, setup of the power tools, doctor.

```text
bxrig power status [--json]
bxrig power profile [performance|balanced|saver]
bxrig power lid suspend|lock|ignore [--yes]
bxrig power setup [--yes] [--force]
bxrig power doctor [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig power profile saver
bxrig power lid lock --yes
bxrig power doctor
```

> `power setup` does nothing on a machine without a battery unless you add --force.

### `bxrig time` {#bxrig-time}

The time zone: show, set, set from your IP after travelling, follow your location, network time.

```text
bxrig time status [--json]
bxrig time zone [--list | ZONE] [--yes]
bxrig time sync [--yes]
bxrig time auto on|off|status [--yes]
bxrig time ntp on|off [--yes]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig time zone Europe/Madrid --yes
bxrig time sync --yes
bxrig time auto on --yes
```

> `time auto on` sends your Wi-Fi networks or IP address to a location web service; the plan says so first.

### `bxrig toggle` {#bxrig-toggle}

Quick switches. Today: stay awake (Noctalia caffeine).

```text
bxrig toggle stay-awake [on|off]
```

```bash
bxrig toggle stay-awake
```

### `bxrig nightshift` {#bxrig-nightshift}

Night light: on, off, toggle, status (sunset to sunrise from your time zone).

```text
bxrig nightshift [on|off|toggle|status] [--location=LAT,LON] [--json]
```

```bash
bxrig nightshift toggle
bxrig nightshift on --location=40.4,-3.7
```

### `bxrig notify` {#bxrig-notify}

Notifications through Noctalia: do not disturb, snooze, history, clear.

```text
bxrig notify dnd on|off|toggle|status | snooze [30m|2h|90s|off] | clear [--history] [--json]
```

```bash
bxrig notify dnd toggle
bxrig notify snooze 2h
bxrig notify clear --history
```

## System and security

Updates, snapshots, DNS, kernels, keys and secrets.

### `bxrig system` {#bxrig-system}

Update the system (a snapshot first), lock, suspend, log out, reboot, shut down.

```text
bxrig system update [--yes] | lock | suspend | logout|reboot|shutdown [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig system update --yes
bxrig system reboot --yes
```

> lock and suspend act at once; logout, reboot and shutdown need --yes (the menu asks first).

### `bxrig security` {#bxrig-security}

Fingerprint and security key for sudo, SSH server, passwordless sudo, with guards.

```text
bxrig security status [--json]
bxrig security fingerprint on|off|enroll [--yes]
bxrig security fido2 on|off|register [--yes]
bxrig security ssh-server on|off [--yes]
bxrig security passwordless-sudo on|off [--yes]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig security status
bxrig security fingerprint on --dry-run
bxrig security passwordless-sudo on --yes
```

> Only /etc/pam.d/sudo is ever changed, with a `sufficient` line and a backup; sudoers is checked with visudo first. `--dry-run` prints the exact line.

### `bxrig dns` {#bxrig-dns}

DNS servers of the active connections: Cloudflare, Google, Quad9, your own, or back to DHCP.

```text
bxrig dns [cloudflare|google|quad9|dhcp|custom IP[,IP...]] [--yes] [--dry-run]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig dns
bxrig dns cloudflare --yes
bxrig dns custom 9.9.9.10 --yes
```

### `bxrig kernel` {#bxrig-kernel}

List, install and remove kernels. Never edits the bootloader.

```text
bxrig kernel list | install NAME | remove NAME [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig kernel list
bxrig kernel install linux-cachyos-lts --yes
```

### `bxrig ssh` {#bxrig-ssh}

Create an SSH key (ed25519; an existing one is kept).

```text
bxrig ssh key [--email=ADDRESS] [--yes] [--dry-run] [--json]
```

```bash
bxrig ssh key --email=me@example.com --yes
```

### `bxrig secrets` {#bxrig-secrets}

API keys and tokens in the system keyring, loaded per command, exported encrypted.

```text
bxrig secrets status | setup [--keyring=kwallet|gnome-keyring|none] [--yes] | list [--type=ai|other] | set NAME [--from-file=F] [--type=ai|other] [--provider=ID] | get NAME [--show] | unset NAME --yes | apply [--yes] | global on NAME --yes|off NAME|show | unlock | lock | export FILE [--plain] [--force] --yes | import FILE [--overwrite] --yes | env [NAMES...] | run [NAMES...] [--strict] -- COMMAND [ARGS...] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig secrets set ANTHROPIC_API_KEY
bxrig secrets run ANTHROPIC_API_KEY -- claude
bxrig secrets list
```

### `bxrig vpn` {#bxrig-vpn}

VPN post-install steps for NordVPN.

```text
bxrig vpn nordvpn setup [--yes] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig vpn nordvpn setup --yes
```

### `bxrig cloud` {#bxrig-cloud}

Cloud storage with rclone: remotes, mounts as systemd user units.

```text
bxrig cloud remotes | configure | mount NAME [--path=DIR] [--yes] | unmount NAME [--yes] | status [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig cloud remotes
bxrig cloud mount gdrive --path=~/Drive --yes
```

### `bxrig settings` {#bxrig-settings}

Export and import your BxRig settings as one archive.

```text
bxrig settings export FILE.tar.gz [--force] | import FILE.tar.gz [--yes] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig settings export my-settings.tar.gz
bxrig settings import my-settings.tar.gz --yes
```

### `bxrig dotfiles` {#bxrig-dotfiles}

Apply your dotfiles repo with chezmoi, yadm, stow or plain links, never overwriting unasked, with undo.

```text
bxrig dotfiles plan REPO [--method=chezmoi|yadm|stow|links] | apply REPO [--method=M] [--overwrite] [--yes] [--dry-run] | status | undo [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig dotfiles plan https://github.com/me/dotfiles
bxrig dotfiles apply https://github.com/me/dotfiles --yes
```

### `bxrig nas` {#bxrig-nas}

Your NAS boxes: find them, save their details, list shares, mount them (also automatically), test them, mirror folders to them, use one as a backup target.

```text
bxrig nas setup [--yes]
bxrig nas discover [--json]
bxrig nas add NAME --host=H [--protocol=smb|nfs] [--user=U] [--vers=3.1.1] [--ask-password | --password-file=F]
bxrig nas list | show NAME | remove NAME [--yes]
bxrig nas shares NAME
bxrig nas mount|unmount NAME SHARE [--yes]
bxrig nas auto on|off NAME SHARE [--yes]
bxrig nas test NAME [SHARE]
bxrig nas sync NAME SRC --to=SHARE[/PATH] [--delete] [--yes]
bxrig nas use NAME SHARE [--path=bxrig-backup]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig nas discover
bxrig nas add synology --host=ds920.local --user=me --ask-password
bxrig nas shares synology
bxrig nas mount synology backups --yes
bxrig nas auto on synology backups --yes
bxrig nas use synology backups
```

> SMB mounts are made by root, so the password is also kept in /etc/bxrig/nas/NAME.cred (mode 600); the plan says so. The SMB version is negotiated unless you give --vers. Nothing on the NAS is deleted unless you add --delete to a sync.

### `bxrig backup` {#bxrig-backup}

Backups of your BxRig setup, of the system and of your files, and a way to move them around.

```text
bxrig backup config now [--reason=TEXT] [--with-secrets]
bxrig backup config list | show ID | diff ID
bxrig backup config restore ID [--only=PATH] [--packages] [--yes] [--dry-run]
bxrig backup config auto on|off|status | prune [--keep=N] [--yes]
bxrig backup config paths | add PATH | remove PATH
bxrig backup snapshots status | list [--json]
bxrig backup snapshots setup [--home] [--yes]
bxrig backup snapshots create [--description=TEXT] [--yes]
bxrig backup snapshots delete ID | changes ID | restore ID PATH [--yes]
bxrig backup data status | targets [--json]
bxrig backup data target add NAME --type=local|sftp|rest|s3|b2|azure|gs|rclone [--path=P --host=H --user=U --url=U --bucket=B --endpoint=URL --region=R --container=C --project=ID --credentials=FILE --remote=R] [--ask-keys | --keys-file=F]
bxrig backup data target remove NAME [--yes]
bxrig backup data init NAME [--yes]
bxrig backup data run [--target=NAME] [--yes]
bxrig backup data list [--target=NAME] | files ID [PATH] | restore ID --to=DIR [--include=PATH] [--yes]
bxrig backup data verify [--deep] | forget [--yes] | retention [--daily=N --weekly=N --monthly=N]
bxrig backup data schedule hourly|daily|off|status [--yes]
bxrig backup data include|exclude add|remove PATH_OR_PATTERN
bxrig backup send ID|all --to=TARGET [--from=TARGET] [--yes]
bxrig backup export data ID --to=FILE.tar|FILE.zip [--path=/PATH] [--target=NAME] [--yes]
bxrig backup export config ID --to=FILE.tar.gz [--yes]
bxrig backup timeline [--local] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig backup config now
bxrig backup config list
bxrig backup config diff 20261113T153000
bxrig backup config restore 20261113T153000 --dry-run
bxrig backup config restore 20261113T153000 --only=.config/hypr --yes
bxrig backup snapshots setup --yes
bxrig backup snapshots list
bxrig backup snapshots restore 12 /home/me/projects/app --dry-run
bxrig backup data target add do --type=s3 --endpoint=https://nyc3.digitaloceanspaces.com --bucket=mybackups --ask-keys
bxrig backup data init do --yes
bxrig backup data run --yes
bxrig backup data schedule daily --yes
bxrig backup data restore latest --to=~/restored --yes
bxrig backup send latest --from=usb --to=do --yes
bxrig backup export data latest --to=~/projects.zip --path=/home/me/Projects --yes
bxrig backup export config 20261113T153000 --to=~/my-setup.tar.gz --yes
bxrig backup timeline --local
```

> A config snapshot is taken by itself before update, system update, init, reinstall and refresh (turn it off with backup config auto off). Secrets and SSH keys are never in it unless you add --with-secrets, which stores your secrets export, encrypted with a passphrase you type.

### `bxrig timemachine` {#bxrig-timemachine}

BxTimeMachine: every backup of your system, setup and files on one timeline, with browse, restore, export and send.

```text
bxrig timemachine [--demo] [--local]
```

```bash
bxrig timemachine
bxrig timemachine --local
bxrig timemachine --demo
```

> It needs a terminal (also available as bxtimemachine). Restore, export, send and back up now show the plan first and change nothing until you press y. --local skips the network targets so it opens at once; --demo shows made-up data and runs nothing.

### `bxrig java` {#bxrig-java}

Your Java homes: list them, install a JDK (through SDKMAN when you have it), choose the default for new shells.

```text
bxrig java list | available | install MAJOR|IDENTIFIER [--yes] [--dry-run] | default ID|MAJOR [--yes] | default --unset [--yes] | remove ID [--yes] | env [ID|MAJOR] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig java list
bxrig java install 21 --yes
bxrig java default 21 --yes
bxrig java env 17
```

> Homes come from SDKMAN, BxRig's own Temurin installs (~/.local/share/bxrig/java) and /usr/lib/jvm. With SDKMAN installed (bxrig sdk setup) installs and removals go through it: a major like 21 picks the newest Temurin, an identifier like 21.0.13.0+9-tem installs exactly that. Without it a Temurin JDK is downloaded straight from Adoptium. The system's own JDKs are never deleted. The default is written to java.sh and java.fish, which the shell starters source, so run bxrig refresh shell once on an existing setup.

### `bxrig sdk` {#bxrig-sdk}

Java, Maven and Gradle through SDKMAN: install, switch, remove.

```text
bxrig sdk status | setup [--yes] | list java|maven|gradle | available java|maven|gradle | install CANDIDATE VERSION [--yes] | default CANDIDATE VERSION [--yes] | remove CANDIDATE VERSION [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig sdk setup --yes
bxrig sdk available maven
bxrig sdk install maven 3.9.9 --yes
bxrig sdk default gradle 8.10.2 --yes
```

> setup installs SDKMAN into ~/.sdkman without touching your shell files. Maven and Gradle reach your shells through ~/.config/bxrig/sdk.sh and sdk.fish, which the shell starters source (bxrig refresh shell on an existing setup). Version lists come from api.sdkman.io.

### `bxrig mail` {#bxrig-mail}

A mail catcher for development: a local inbox for the mail your apps send, in a container.

```text
bxrig mail start [--keep] [--smtp-port=N] [--ui-port=N] [--yes] | stop | status | remove [--keep-data] [--yes] | list [--limit=N] | show ID | delete ID [--yes] | clear [--yes] | open [ID] | test [--to=ADDR] [--subject=TEXT] | env [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig mail start --yes
bxrig mail env
bxrig mail test
bxrig mail list
bxrig mail start --keep --yes
```

> Runs Mailpit in a container (the engine bxrig db engine chose). SMTP is 127.0.0.1:1025 and the web inbox is http://127.0.0.1:8025, both local only. Mail is thrown away when the catcher stops unless you start it with --keep. The Control Center has a Mail page that refreshes by itself.

### `bxrig tui` {#bxrig-tui}

Control Center: every BxRig screen in one terminal, or one page on its own.

```text
bxrig tui [PAGE] [--sidebar|--no-sidebar] [--demo] [--icons=on|off] [--json]
bxrig tui list [--json]
```

```bash
bxrig tui
bxrig tui databases
bxrig tui list
bxrig tui dashboard --json
bxrig tui --demo
```

> It needs a terminal. `bxrig tui` opens the Control Center with the sidebar; `bxrig tui PAGE` opens that page alone with the sidebar collapsed, like an app of its own (an unknown page exits 2). The backslash key or Ctrl+b (or a click on the left strip or the breadcrumb) opens and closes the sidebar, Tab and Shift+Tab still change page, and Left opens a collapsed sidebar. --sidebar and --no-sidebar force it either way; below 90 columns it starts collapsed. Nothing is remembered. `tui list` prints the page ids and titles. Enter on a warning shows the plan of the fix before anything changes. --json prints a page's data without a terminal; --demo shows made-up data and runs nothing. Icons are Nerd Font glyphs: on when a Nerd Font is installed, or force them with --icons=on|off or BXRIG_ICONS.

### `bxrig bxtimemachine` {#bxrig-bxtimemachine}

The same as timemachine: BxTimeMachine, your backups through time.

```text
bxrig bxtimemachine [--demo] [--local]
```

```bash
bxrig bxtimemachine
```

## Develop

BoxLang, editors, databases, containers, virtual machines and AI agents.

### `bxrig boxlang` {#bxrig-boxlang}

BoxLang status, modules (ForgeBox), the VS Code extension, links.

```text
bxrig boxlang status | use VERSION | matchbox use VERSION | modules list|search TEXT|install SLUG...|installed|outdated|update | vscode | links | welcome [--json]
```

```bash
bxrig boxlang status
bxrig boxlang modules list
bxrig boxlang use 1.8.0
```

### `bxrig editor` {#bxrig-editor}

Neovim with LazyVim, the BoxLang plugin and themes that follow the BxRig theme.

```text
bxrig editor lazyvim [--yes] | boxlang [--yes] | status | refresh [--force] [--yes] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig editor lazyvim --yes
bxrig editor status
```

### `bxrig db` {#bxrig-db}

Databases as containers (Podman or Docker): PostgreSQL, MySQL, Redis, MongoDB, Couchbase, vector stores.

```text
bxrig db engines | list | start ENGINE [--name N] [--port P] [--password-file FILE | --ask-password] [--yes] [--dry-run] | stop|status|logs ENGINE [--name N] | remove ENGINE [--name N] [--keep-data] --yes | info ENGINE [--name N] [--show-password] | engine [podman|docker] | menu [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig db engines
bxrig db start postgres --yes
bxrig db info postgres
```

### `bxrig containers` {#bxrig-containers}

Podman helpers: doctor, rootless socket, docker compatibility wrappers.

```text
bxrig containers doctor | socket enable [--yes] | docker-compat [--yes] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig containers doctor
```

### `bxrig vm` {#bxrig-vm}

Virtual machines in containers: Windows (dockur) and Linux desktops (webtop), with sizes and status.

```text
bxrig vm list | status [NAME] | size [NAME] | info NAME [--show-password] | doctor | versions linux|windows | create windows [NAME] [--version=V] [--ram=8G] [--cpus=N] [--disk=64G] [--share=PATH|none] | create linux NAME [--tag=ubuntu-xfce] [--cpus=N] [--memory=4G] [--share=PATH|none] [--gpu=none|auto|intel|amd|nvidia] | start|stop|logs NAME | open NAME [--web] [--fullscreen] | remove NAME [--keep-data] [--yes] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig vm doctor
bxrig vm create linux dev --tag=ubuntu-xfce --yes
bxrig vm open dev
```

### `bxrig ai` {#bxrig-ai}

AI agents: list, default, launch, tmux sessions, local models, the pull-down AI shell.

```text
bxrig ai session start [ID] [--name=N] [--dir=PATH] [--dry-run] | list | attach NAME | stop NAME --yes [--json]
bxrig ai models list | ps | pull NAME | rm NAME --yes | status | enable [--yes] [--json]
bxrig ai list | default [ID] [--yes] | launch [ID] [--dry-run] | session ... | models ... | shell [toggle|status] [--backend=hyprland|yakuake] [--dry-run] [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig ai list
bxrig ai launch
bxrig ai models pull llama3.2
bxrig ai session start --name=work
```

### `bxrig skills` {#bxrig-skills}

Agent skills for BoxLang and BxRig: install, update, remove.

```text
bxrig skills list [--tag=T] | search TEXT | show OWNER/REPO/SLUG | install [bxrig|boxlang|matchbox|OWNER/REPO/SLUG]... [--yes] | installed | update [--yes] | remove NAME [--yes] | status | link [--json]
```

Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.

```bash
bxrig skills install --yes
bxrig skills list
bxrig skills status
```

## Everyday tools

Screenshots, clipboard, windows, dictation and hardware helpers.

### `bxrig screenshot` {#bxrig-screenshot}

Screenshots: screen, region, window, OCR text, QR codes, or a menu.

```text
bxrig screenshot screen|region|window [--edit] | ocr | qr | menu [--dry-run] [--json]
```

```bash
bxrig screenshot region
bxrig screenshot screen --edit
bxrig screenshot ocr
```

### `bxrig qr` {#bxrig-qr}

Make a QR code from text (printed in the terminal, or saved with --out).

```text
bxrig qr TEXT [--out=FILE.png] [--json]
```

```bash
bxrig qr https://boxlang.io
bxrig qr 'wifi text' --out=wifi.png
```

### `bxrig record` {#bxrig-record}

Screen recording: start, stop, toggle.

```text
bxrig record [toggle|start|stop|status] [--region] [--dry-run] [--json]
```

```bash
bxrig record toggle
bxrig record start --region
```

### `bxrig clipboard` {#bxrig-clipboard}

Clipboard history (cliphist): pick, list, clear, setup.

```text
bxrig clipboard pick | clear [--yes] | status [--json]
```

```bash
bxrig clipboard pick
bxrig clipboard status
```

### `bxrig emoji` {#bxrig-emoji}

The emoji picker (rofimoji).

```text
bxrig emoji
```

```bash
bxrig emoji
```

### `bxrig forcequit` {#bxrig-forcequit}

Pick a window or process and force quit it.

```text
bxrig forcequit
```

```bash
bxrig forcequit
```

### `bxrig window` {#bxrig-window}

Minimize and restore windows.

```text
bxrig window minimize|restore
```

```bash
bxrig window minimize
bxrig window restore
```

### `bxrig overview` {#bxrig-overview}

The workspace and window overview.

```text
bxrig overview [setup]
```

```bash
bxrig overview
```

### `bxrig quicklook` {#bxrig-quicklook}

Quick Look for files (Kiview): preview with a key.

```text
bxrig quicklook [PATH] [--dry-run] [--json]
```

```bash
bxrig quicklook photo.jpg
```

### `bxrig dolphin` {#bxrig-dolphin}

Dolphin diagnostics: why it is slow or missing features.

```text
bxrig dolphin doctor [--fix] [--json]
```

```bash
bxrig dolphin doctor
bxrig dolphin doctor --fix
```

### `bxrig dictation` {#bxrig-dictation}

Dictation with Superwhisper or Voxtype: setup and toggle.

```text
bxrig dictation setup [superwhisper|voxtype] [--yes] [--dry-run] | status | key [ENGINE] [--json]
```

```bash
bxrig dictation setup voxtype --yes
bxrig dictation status
```

### `bxrig strata` {#bxrig-strata}

Strata, the file manager: its integrations.

```text
bxrig strata integrations [--dry-run] [--json]
```

```bash
bxrig strata integrations --dry-run
```

### `bxrig gpu` {#bxrig-gpu}

GPU check: driver, rendering, NVIDIA specifics.

```text
bxrig gpu doctor [--json]
```

```bash
bxrig gpu doctor
```

### `bxrig input` {#bxrig-input}

Input devices: doctor, trackpad gestures.

```text
bxrig input doctor | gestures [--yes] [--dry-run] [--json]
```

```bash
bxrig input doctor
```

### `bxrig airplay` {#bxrig-airplay}

AirPlay receiver: on, off, status.

```text
bxrig airplay on|off|status [--json]
```

```bash
bxrig airplay on
```

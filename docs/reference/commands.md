---
title: Command reference
order: 1
summary: Every command, from the program itself.
---

# Command reference

Generated from the usage text in `src/Main.bx` (`bootstrap/gen-docs.sh` rewrites it). Every command accepts `--json`; commands that change the system print a plan and need `--yes`, and `--dry-run` shows the plan and exits 0. See the [command contract](../architecture/COMMAND-CONTRACT.md) for exit codes and details.

### `bxcachy ai`

```text
bxcachy ai list | default [ID] [--yes] | launch [ID] [--dry-run] | session ... | models ... | shell [toggle|status] [--backend=hyprland|yakuake] [--dry-run] [--json]
```

### `bxcachy ai`

```text
bxcachy ai models list | ps | pull NAME | rm NAME --yes | status | enable [--yes] [--json]
```

### `bxcachy ai`

```text
bxcachy ai session start [ID] [--name=N] [--dir=PATH] [--dry-run] | list | attach NAME | stop NAME --yes [--json]
```

### `bxcachy airplay`

```text
bxcachy airplay on|off|status [--json]
```

### `bxcachy apps`

```text
bxcachy apps | apps list [--json]
```

### `bxcachy assets`

```text
bxcachy assets list | install [--yes] [--dry-run] [--json]
```

### `bxcachy boxlang`

```text
bxcachy boxlang status | use VERSION | matchbox use VERSION | modules list|search TEXT|install SLUG...|installed|outdated|update | vscode | links | welcome [--json]
```

### `bxcachy catalog`

```text
bxcachy catalog list [--group=G] [--category=C] [--tier=default|optional] [--kind=K] [--source=S] [--json] | show ID | groups | check | version
```

### `bxcachy clipboard`

```text
bxcachy clipboard pick | clear [--yes] | status [--json]
```

### `bxcachy cloud`

```text
bxcachy cloud remotes | configure | mount NAME [--path=DIR] [--yes] | unmount NAME [--yes] | status [--json]
```

### `bxcachy config`

```text
bxcachy config list|diff NAME|apply NAME|restore NAME ID|history [NAME] [--yes] [--dry-run] [--force] [--json]
```

### `bxcachy config`

```text
bxcachy config restore NAME ID --yes
```

### `bxcachy containers`

```text
bxcachy containers doctor | socket enable [--yes] | docker-compat [--yes] [--json]
```

### `bxcachy default`

```text
bxcachy default show | browser ID | terminal ID | filemanager ID [--yes] [--dry-run] [--json]
```

### `bxcachy dictation`

```text
bxcachy dictation setup [superwhisper|voxtype] [--yes] [--dry-run] | status | key [ENGINE] [--json]
```

### `bxcachy dolphin`

```text
bxcachy dolphin doctor [--fix] [--json]
```

### `bxcachy editor`

```text
bxcachy editor lazyvim [--yes] | boxlang [--yes] | status | refresh [--force] [--yes] [--json]
```

### `bxcachy gpu`

```text
bxcachy gpu doctor [--json]
```

### `bxcachy init`

```text
bxcachy init [--from=FILE] [--fresh | --rerun] | init --answers=FILE [--yes] [--dry-run] [--json] | init --print-answers [--from-system] [--json] | init --export=FILE [--force]
```

### `bxcachy input`

```text
bxcachy input doctor | gestures [--yes] [--dry-run] [--json]
```

### `bxcachy keys`

```text
bxcachy keys show | mac [on|off|status] [--yes] | set ID KEYS [--yes] [--force] | reset ID [--yes] | conflicts | render xremap|hyprland|plasma | check | apply [--yes] [--dry-run] [--force] [--json]
```

### `bxcachy layout`

```text
bxcachy layout [toggle|float|tile|status] [--dry-run] [--json]
```

### `bxcachy menu`

```text
bxcachy menu | menu items [--json] | menu search TEXT [--json]
```

### `bxcachy nightshift`

```text
bxcachy nightshift [on|off|toggle|status] [--location=LAT,LON] [--json]
```

### `bxcachy notify`

```text
bxcachy notify dnd on|off|toggle|status | snooze [30m|2h|90s|off] | clear [--history] [--json]
```

### `bxcachy pkg`

```text
bxcachy pkg search TEXT [--source=all|repo|aur] [--limit=N] | info NAME | installed [--explicit] | install NAME... [--aur] [--yes] [--dry-run] | remove NAME... [--yes] [--dry-run] [--json]
```

### `bxcachy plasma`

```text
bxcachy plasma panels apply [--agenda] [--without-weather] [--desktops=N] [--preset=NAME] | undo | status [--yes] [--dry-run] [--json]  |  plasma desktops N [--yes]
```

### `bxcachy qr`

```text
bxcachy qr TEXT [--out=FILE.png] [--json]
```

### `bxcachy quicklook`

```text
bxcachy quicklook [PATH] [--dry-run] [--json]
```

### `bxcachy record`

```text
bxcachy record [toggle|start|stop|status] [--region] [--dry-run] [--json]
```

### `bxcachy screenshot`

```text
bxcachy screenshot screen|region|window [--edit] | ocr | qr | menu [--dry-run] [--json]
```

### `bxcachy secrets`

```text
bxcachy secrets status | setup [--keyring=kwallet|gnome-keyring|none] [--yes] | list [--type=ai|other] | set NAME [--from-file=F] [--type=ai|other] [--provider=ID] | get NAME [--show] | unset NAME --yes | apply [--yes] | global on NAME --yes|off NAME|show | unlock | lock | export FILE [--plain] [--force] --yes | import FILE [--overwrite] --yes | env [NAMES...] | run [NAMES...] [--strict] -- COMMAND [ARGS...] [--json]
```

### `bxcachy session`

```text
bxcachy session show | set hyprland|plasma [--yes] [--dry-run] [--json]
```

### `bxcachy settings`

```text
bxcachy settings export FILE.tar.gz [--force] | import FILE.tar.gz [--yes] [--json]
```

### `bxcachy setup`

```text
bxcachy setup plasma [--keys | --undo-keys] | hyprland [--terminal=ghostty|kitty|alacritty|foot|konsole] [--layout=dwindle|master|scrolling|floating] [--workspaces=N] [--natural-scroll] [--layouts=us-intl,es] [--theme=dark|light|auto] [--wallpaper=box|grid|aurora|minimal] | terminal [--default=ghostty] [--also=a,b] | shell [--shell=zsh|fish|bash] | keyboard [--layouts=us-intl,es] | xremap [--build=hypr|kde] | undo plasma|hyprland|xremap | status [--yes] [--dry-run] [--json]
```

### `bxcachy skills`

```text
bxcachy skills list [--tag=T] | search TEXT | show OWNER/REPO/SLUG | install [bxcachy|boxlang|matchbox|OWNER/REPO/SLUG]... [--yes] | installed | update [--yes] | remove NAME [--yes] | status | link [--json]
```

### `bxcachy ssh`

```text
bxcachy ssh key [--email=ADDRESS] [--yes] [--dry-run] [--json]
```

### `bxcachy status`

```text
bxcachy status [--json]
```

### `bxcachy strata`

```text
bxcachy strata integrations [--dry-run] [--json]
```

### `bxcachy system`

```text
bxcachy system update [--yes] | lock | suspend | logout|reboot|shutdown [--yes] [--dry-run] [--json]
```

### `bxcachy theme`

```text
bxcachy theme list | show NAME | set NAME [--mode=theme|dark|light|auto] [--keep-wallpaper] | random | next | mode theme|dark|light|auto | install GIT_URL [--name=N] [--force] | import PATH [--name=N] [--force] | remove NAME | status [--dry-run] [--json]
```

### `bxcachy tiling`

```text
bxcachy tiling on|off|status | layout [dwindle|master|monocle|scrolling|stage] [--json]
```

### `bxcachy toolchain`

```text
bxcachy toolchain node [--yes] [--dry-run] [--json]   (Bun and Deno: bxcachy install bun deno)
```

### `bxcachy update`

```text
bxcachy update check [--notify] | apply [--yes] | channel [stable|beta] | notifications on|off|status [--json]
```

### `bxcachy vm`

```text
bxcachy vm list | status [NAME] | size [NAME] | info NAME [--show-password] | doctor | versions linux|windows | create windows [NAME] [--version=V] [--ram=8G] [--cpus=N] [--disk=64G] [--share=PATH|none] | create linux NAME [--tag=ubuntu-xfce] [--cpus=N] [--memory=4G] [--share=PATH|none] [--gpu=none|auto|intel|amd|nvidia] | start|stop|logs NAME | open NAME [--web] [--fullscreen] | remove NAME [--keep-data] [--yes] [--dry-run] [--json]
```

### `bxcachy vpn`

```text
bxcachy vpn nordvpn setup [--yes] [--json]
```

### `bxcachy web`

```text
bxcachy web add [NAME URL] [--browser=brave|chromium|google-chrome|edge|firefox] [--yes] | list | rm NAME [--yes] | install google|microsoft|apple|boxlang|all [--yes] [--dry-run] [--json]
```

### `bxcachy window`

```text
bxcachy window minimize|restore
```

### `bxcachy wizard`

```text
bxcachy wizard --demo [--out=FILE] | --pages=FILE [--out=FILE] [--answers=FILE]
```


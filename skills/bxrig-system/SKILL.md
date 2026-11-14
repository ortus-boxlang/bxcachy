---
name: bxrig-system
description: "Use this skill when changing how a BxRig machine looks or behaves at the system level: the bar, dock, windows, fonts and backgrounds (appearance), monitors and brightness (display), laptop power and the lid (power), the time zone and travel (time), DNS, kernels, stay awake, fingerprint or security key for sudo, passwordless sudo, or the SSH server."
---

# BxRig: appearance, hardware and system settings

Every command below follows the BxRig rules (plan without `--yes`, `--dry-run`, `--json`). Settings that only touch the user's own config (appearance, display, theme) act at once.

## Look

- `bxrig appearance bar position|style|clock|battery|show|hide|toggle`, `dock mode|position|show|hide|toggle`, `windows gaps|corners|opacity|one-window-ratio`, `animations on|off`, `layout dwindle|scrolling|floating`, `font list|ID|install ID --yes`, `background list|set|next|random`, `apply`. Choices are remembered in `~/.config/bxrig/appearance.json`; Hyprland looks go to the generated `~/.config/bxrig/theme/look.lua`. Colors are `bxrig theme`.

## Hardware

- Monitors: `bxrig display list|scale NAME V|rotate NAME DEG|mode NAME M|position NAME XxY|mirror on|off|laptop on|off|brightness up|down|set N|apply|reset`. Hyprland writes `theme/monitors.lua`; Plasma uses `kscreen-doctor`. Turning the laptop panel off is refused when no other monitor would stay on.
- Laptop power: `bxrig power status|profile performance|balanced|saver|lid suspend|lock|ignore --yes|setup --yes|doctor`. `setup` does nothing without a battery (add `--force` to override).
- `bxrig toggle stay-awake [on|off]` (Noctalia). `bxrig dns [cloudflare|google|quad9|dhcp|custom IPS] --yes`.

## Time and travel

- `bxrig time status`, `time zone [--list|ZONE] --yes`, `time sync --yes` (set the zone from the IP address after travelling), `time auto on|off --yes` (follow the location; this sends Wi-Fi or IP data to a location service, say so before applying), `time ntp on|off --yes`.

## Kernels and security

- `bxrig kernel list|install NAME --yes|remove NAME --yes`: never edits the bootloader, never removes the running or last kernel.
- `bxrig security status|fingerprint on|off|enroll|fido2 register|on|off|ssh-server on|off|passwordless-sudo on|off --yes`: only `/etc/pam.d/sudo` is changed, with a `sufficient` line, a backup and a marker; sudoers is checked with `visudo -cf` first. Always show the user `--dry-run` first, and tell them to keep a root terminal open the first time.

## Backups, NAS and BxTimeMachine

- `bxrig backup config now|list|diff ID|restore ID [--only=PATH] --yes|auto on|off|export` (BxRig setup snapshots, automatic before updates). `bxrig backup snapshots setup|list|create|restore ID PATH` (snapper on Btrfs, Timeshift elsewhere; no automatic rollback). `bxrig backup data target add NAME --type=s3|b2|azure|gs|sftp|rest|rclone|local ... [--ask-keys]`, then `init NAME --yes`, `run --all --yes`, `list`, `restore ID --to=DIR`, `verify`, `forget`, `schedule daily|hourly|off --yes`. `backup send ID --from=A --to=B` and `backup export data|config ID --to=FILE`. Keys and repository passwords live in the keyring; never ask for or print them.
- `bxrig nas discover|add NAME --host=H --user=U --ask-password|shares|mount NAME SHARE --yes|auto on NAME SHARE --yes|test|sync|use NAME SHARE`. SMB mounts use a root-only credentials file; say so before applying.
- `bxrig timemachine` (alias `bxtimemachine`) is BxTimeMachine, the backup screen; `backup timeline --json` is the same data for scripts. It needs a terminal.

## Finding commands

- `bxrig help` lists every command by group; `bxrig help NAME` shows its usage and examples. `bxrig menu search TEXT` finds a menu entry.

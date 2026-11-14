---
name: bxcachy-system
description: "Use this skill when changing how a BxCachy machine looks or behaves at the system level: the bar, dock, windows, fonts and backgrounds (appearance), monitors and brightness (display), laptop power and the lid (power), the time zone and travel (time), DNS, kernels, stay awake, fingerprint or security key for sudo, passwordless sudo, or the SSH server."
---

# BxCachy: appearance, hardware and system settings

Every command below follows the BxCachy rules (plan without `--yes`, `--dry-run`, `--json`). Settings that only touch the user's own config (appearance, display, theme) act at once.

## Look

- `bxcachy appearance bar position|style|clock|battery|show|hide|toggle`, `dock mode|position|show|hide|toggle`, `windows gaps|corners|opacity|one-window-ratio`, `animations on|off`, `layout dwindle|scrolling|floating`, `font list|ID|install ID --yes`, `background list|set|next|random`, `apply`. Choices are remembered in `~/.config/bxcachy/appearance.json`; Hyprland looks go to the generated `~/.config/bxcachy/theme/look.lua`. Colors are `bxcachy theme`.

## Hardware

- Monitors: `bxcachy display list|scale NAME V|rotate NAME DEG|mode NAME M|position NAME XxY|mirror on|off|laptop on|off|brightness up|down|set N|apply|reset`. Hyprland writes `theme/monitors.lua`; Plasma uses `kscreen-doctor`. Turning the laptop panel off is refused when no other monitor would stay on.
- Laptop power: `bxcachy power status|profile performance|balanced|saver|lid suspend|lock|ignore --yes|setup --yes|doctor`. `setup` does nothing without a battery (add `--force` to override).
- `bxcachy toggle stay-awake [on|off]` (Noctalia). `bxcachy dns [cloudflare|google|quad9|dhcp|custom IPS] --yes`.

## Time and travel

- `bxcachy time status`, `time zone [--list|ZONE] --yes`, `time sync --yes` (set the zone from the IP address after travelling), `time auto on|off --yes` (follow the location; this sends Wi-Fi or IP data to a location service, say so before applying), `time ntp on|off --yes`.

## Kernels and security

- `bxcachy kernel list|install NAME --yes|remove NAME --yes`: never edits the bootloader, never removes the running or last kernel.
- `bxcachy security status|fingerprint on|off|enroll|fido2 register|on|off|ssh-server on|off|passwordless-sudo on|off --yes`: only `/etc/pam.d/sudo` is changed, with a `sufficient` line, a backup and a marker; sudoers is checked with `visudo -cf` first. Always show the user `--dry-run` first, and tell them to keep a root terminal open the first time.

## Backups, NAS and BxTimeMachine

- `bxcachy backup config now|list|diff ID|restore ID [--only=PATH] --yes|auto on|off|export` (BxCachy setup snapshots, automatic before updates). `bxcachy backup snapshots setup|list|create|restore ID PATH` (snapper on Btrfs, Timeshift elsewhere; no automatic rollback). `bxcachy backup data target add NAME --type=s3|b2|azure|gs|sftp|rest|rclone|local ... [--ask-keys]`, then `init NAME --yes`, `run --all --yes`, `list`, `restore ID --to=DIR`, `verify`, `forget`, `schedule daily|hourly|off --yes`. `backup send ID --from=A --to=B` and `backup export data|config ID --to=FILE`. Keys and repository passwords live in the keyring; never ask for or print them.
- `bxcachy nas discover|add NAME --host=H --user=U --ask-password|shares|mount NAME SHARE --yes|auto on NAME SHARE --yes|test|sync|use NAME SHARE`. SMB mounts use a root-only credentials file; say so before applying.
- `bxcachy timemachine` (alias `bxtimemachine`) is BxTimeMachine, the backup screen; `backup timeline --json` is the same data for scripts. It needs a terminal.

## Finding commands

- `bxcachy help` lists every command by group; `bxcachy help NAME` shows its usage and examples. `bxcachy menu search TEXT` finds a menu entry.

# BxCachy

A developer-machine kickstarter for [CachyOS](https://cachyos.org). One command installs the toolchains, the desktop and your apps, then a setup wizard configures the rest. Hyprland with Noctalia is the default desktop, with KDE Plasma installed beside it and tiled by the same shortcuts.

BxCachy is a [BoxLang](https://boxlang.io) program compiled to a native executable with [MatchBox](https://github.com/ortus-boxlang/matchbox).

Docs: <https://bxcachy.boxlang.io> (built with bxSites from `docs/`).

## Install

```bash
curl -fsSL https://downloads.ortussolutions.com/ortussolutions/bxcachy/install.sh | bash
```

It shows the plan, asks once, installs, and starts the wizard. The release information is signed (Ed25519) and checked before anything is installed.

Unattended, with saved answers:

```bash
curl -fsSL https://downloads.ortussolutions.com/ortussolutions/bxcachy/install.sh | bash -s -- --yes --answers answers.json
```

Add `--channel beta` for the bleeding-edge snapshots. Update later with `bxcachy update apply --yes`.

## What you get

| Area | What |
|---|---|
| Toolchains | Java 21, bvm, mvm, BoxLang, MatchBox, Rust. Optional: PHP, Python, Go, JavaScript runtimes |
| Desktop | Hyprland and Noctalia, KDE Plasma with HyprKwin tiling, one shared shortcut table (including Mac-style Cmd remaps), key cheat sheet |
| Control center | `bxcachy menu`: every command as one searchable menu on your launcher (Rofi, Walker, Wofi, Fuzzel, Vicinae) |
| Appearance and hardware | Bar, dock, windows, fonts, backgrounds, monitors, laptop power, time zone and DNS, each one command (`appearance`, `display`, `power`, `time`, `dns`) |
| Backups | BxCachy setup snapshots, system snapshots (snapper), encrypted file backups (restic) to a NAS, a disk or the cloud, and **BxTimeMachine**, one screen for all of them (`bxcachy timemachine`) |
| NAS | Synology or any SMB or NFS share: discover, mount, automatic mounts, mirror (`bxcachy nas`) |
| Themes | 15 color themes in the Omarchy format (10 from Omarchy, 5 of ours); follows into terminals, btop, window borders and Neovim |
| Shell and editor | zsh, fish or bash with Starship (shows the BoxLang version), Ghostty and other terminals, Neovim with LazyVim and BoxLang syntax |
| Apps | A curated catalog of about 290 apps by category, chosen in the wizard |
| Databases | PostgreSQL, MySQL, Redis, MongoDB, vector databases and more as local containers (`bxcachy db`) |
| Virtual machines | Windows and Linux desktops in containers, any number of each (`bxcachy vm`) |
| AI | Coding agents, local models, API keys in your keyring (`bxcachy secrets`), and agent skills for Claude Code, Codex, Gemini CLI and OpenCode (`bxcachy skills`) |
| Safety | Every change is a plan until `--yes`; config files go through a backup and journal service and your own edits are never overwritten |

## Everyday commands

```bash
bxcachy init                    # the wizard
bxcachy menu                    # the control center
bxcachy status                  # what is set up on this machine
bxcachy theme set tokyo-night   # change the look
bxcachy appearance bar position bottom
bxcachy display scale DP-2 1.5
bxcachy time sync --yes         # after you travel
bxcachy timemachine             # every backup on one timeline
bxcachy help                    # every command, or: bxcachy help appearance
bxcachy vm create linux dev     # a Linux desktop in a container
bxcachy db start postgres --yes
bxcachy skills install --yes    # BxCachy, BoxLang and MatchBox skills for your agents
bxcachy update check
```

The full list is in the [command reference](https://bxcachy.boxlang.io/reference/commands/). Every command supports `--json`, and mutating commands support `--dry-run`.

## Exit codes

`0` ok, `2` a plan was shown (no `--yes`) or bad usage, `4` a precondition failed, `5`, `6`, `7` failures, `9` internal error, `10` an update is available.

## Development

```bash
scripts/dev-build.sh                         # builds dist/bxcachy with a local MatchBox (see the script)
bash tests/theme-test.sh dist/bxcachy        # script tests, one per area (fake tools, no root needed)
(cd src && matchbox ../tests/init_plan_test.bxs)   # unit tests
```

Layout:

| Path | Contents |
|---|---|
| `src/Main.bx` | The CLI and its routes |
| `src/bxcachy/` | One class per feature (`Vm`, `Theme`, `Db`, `Skills`, ...) |
| `catalog/apps.json` | The app catalog |
| `templates/`, `themes/`, `assets/`, `skills/` | Starter configs, themes, the wizard definition, images, and the agent skills that ship with BxCachy |
| `bootstrap/` | The one-line installer and the `gen-*.sh` scripts that embed data into generated classes |
| `docs/` | The documentation site; `docs/architecture/COMMAND-CONTRACT.md` is the design record |
| `tests/` | Script and unit tests |

Generated classes (`CatalogData`, `TemplateData`, `ThemeData`, `SkillData`, `WizardData`, `AssetData`, `ReleaseKey`) and `docs/reference/commands.md` are rebuilt by the matching `bootstrap/gen-*.sh`; CI runs each with `--check`.

Changes follow the contract in `docs/architecture/COMMAND-CONTRACT.md`: plan before `--yes`, `--dry-run`, the `--json` envelope, and the exit codes above.

## Status

Version 0.11.0-dev. The tests run against fake tools, so features that need real hardware or a live desktop (Hyprland, Noctalia, KVM virtual machines, GPUs, the signed install from the download bucket) are marked as unverified in the contract until they have been run on a real CachyOS machine.

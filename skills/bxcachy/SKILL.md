---
name: bxcachy
description: "Use this skill when the user asks about BxCachy, the developer-machine setup tool for CachyOS (Hyprland + Noctalia, KDE Plasma): its commands, conventions, config files, how to run it safely, or how to change something on a machine that BxCachy set up."
---

# BxCachy

BxCachy turns a CachyOS install into a finished developer machine: Hyprland with Noctalia (KDE Plasma stays installed beside it), BoxLang and MatchBox, apps, shell, AI agents. It is one native binary, `bxcachy`, written in BoxLang and compiled with MatchBox. Docs: https://bxcachy.boxlang.io

## Rules every command follows

- Read-only commands just run. A command that changes the system prints a **plan** and exits 2 until you add `--yes`. `--dry-run` prints the plan and exits 0.
- `--json` prints one envelope: `{ "command", "data", "exit", "ok", "schema": 1, "version", "warnings", "dry_run" }`. Use it when you parse output.
- Exit codes: 0 ok, 2 plan without `--yes` or bad usage, 4 a precondition failed (tool missing, bad input), 5 or 6 or 7 a step failed. `update check` uses 10 for "update available".
- Never edit generated files blindly: BxCachy keeps a file you changed (it reports it as `drifted`) and only rewrites files it wrote itself.
- Never ask for or print API keys. Secrets live in the desktop keyring (`bxcachy secrets`).

## Where things live

- Settings: `~/.config/bxcachy/` (`answers.json` is the wizard's answers, `shortcuts.json` your key changes, `runner.json`, `update.json`, `skills.json`).
- The binary: `~/.local/bin/bxcachy`. Logs of the installer: `~/.cache/bxcachy/install.log`.
- Hyprland module: `~/.config/hypr/bxcachy.lua` (generated; your `hyprland.lua` is yours).

## Find your way

- `bxcachy status`: what this machine already has. `bxcachy init`: the setup wizard (`--rerun`, `--fresh`, `--defaults --yes`, `--answers FILE --yes`).
- `bxcachy menu`: the control center (also `Super+Alt+M`). `bxcachy keys sheet`: every shortcut (`Super+K`).
- `bxcachy doctor`, `bxcachy gpu doctor`, `bxcachy input doctor`, `bxcachy dolphin doctor`: checks that print a fix for each problem.
- `bxcachy help` lists every command by group, `bxcachy help NAME` shows its usage and examples (the same text as the docs site's command reference).
- More: skills `bxcachy-install-update`, `bxcachy-desktop`, `bxcachy-system`, `bxcachy-apps`, `bxcachy-ai`.

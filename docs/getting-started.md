---
title: Getting started
order: 2
summary: Install BxCachy, run the wizard, and find your way around.
---

# Getting started

## What you need

- CachyOS (or another Arch-based system with `pacman`), x86_64.
- A normal user with `sudo`. The installer refuses to run as root.
- A network connection.

## Install

```bash
curl -fsSL {{ installUrl }} | bash
```

The installer:

1. checks the machine;
2. downloads the program and the install bundle for your [channel](guides/updates.md) and verifies their signature and SHA-256;
3. installs packages, toolchains (Java 21, `bvm`, `mvm`, BoxLang, MatchBox, Rust) and the core apps;
4. starts the [setup wizard](guides/wizard.md).

Its log is `~/.cache/bxcachy/install.log`.

### Without anyone at the keyboard

```bash
curl -fsSL {{ installUrl }} | bash -s -- --yes --answers answers.json
```

`--yes` never asks (it needs passwordless sudo). Without `--answers`, the wizard's default answers are applied. More options: `--channel stable|beta`, `--no-wizard`, `--dry-run`.

## After the install

| Do this | With |
|---|---|
| See what is set up | `bxcachy status` |
| Change your choices | `bxcachy init` |
| Open the control center | `Super+Alt+M` or `bxcachy menu` |
| See every shortcut | `Super+K` or `bxcachy keys sheet` |
| Check for updates | `bxcachy update check` |

New to BoxLang? Run `bxcachy boxlang welcome` for a getting-started page, or open [Try BoxLang](https://try.boxlang.io).

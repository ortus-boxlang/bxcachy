---
title: Getting started
order: 2
summary: Install BxRig, run the wizard, and find your way around.
---

# Getting started

## What you need

**Supported today: CachyOS and Arch Linux. Other distributions (Debian, Ubuntu, Fedora) are the direction, not yet supported.**

- CachyOS or Arch Linux (a system with `pacman`), x86_64.
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

Its log is `~/.cache/bxrig/install.log`.

### Without anyone at the keyboard

```bash
curl -fsSL {{ installUrl }} | bash -s -- --yes --answers answers.json
```

`--yes` never asks (it needs passwordless sudo). Without `--answers`, the wizard's default answers are applied. More options: `--channel stable|beta`, `--no-wizard`, `--dry-run`.

## After the install

| Do this | With |
|---|---|
| See what is set up | `bxrig status` |
| Change your choices | `bxrig init` |
| Open the control center | `Super+Alt+M` or `bxrig menu` |
| See every shortcut | `Super+K` or `bxrig keys sheet` |
| Check for updates | `bxrig update check` |

New to BoxLang? Run `bxrig boxlang welcome` for a getting-started page, or open [Try BoxLang](https://try.boxlang.io).

---
title: Home
order: 1
summary: BxRig brings an opinionated, beautiful and efficient desktop to Linux, built for developers.
---

# BxRig

**BxRig** brings an opinionated, beautiful and efficient desktop to Linux, built for developers. It turns a fresh CachyOS or Arch install into a finished developer rig: Hyprland with Noctalia (KDE Plasma stays installed beside it), BoxLang and MatchBox, your apps, your shell, your AI agents, all chosen in one guided setup. It is a single native program written in [BoxLang](https://boxlang.io) and compiled with [MatchBox](https://matchbox.boxlang.io).

**Supported today: CachyOS and Arch Linux. Other distributions (Debian, Ubuntu, Fedora) are the direction, not yet supported.**

*This is the documentation for version {{ version }}.*

## Install

```bash title="One line"
curl -fsSL {{ installUrl }} | bash
```

It checks your machine, downloads and verifies the release, installs everything, then starts the setup wizard. See [Getting started](getting-started.md).

## What you get

::: card title="A desktop that is ready" href="guides/desktop.md"
Hyprland and Noctalia, or Plasma with tiling and a status panel. Mac-style keys, screenshots, notifications, night shift.
:::

::: card title="One menu for everything" href="guides/menu.md"
The control center: search every setting, install any package, change the look, monitors, power, time zone and DNS.
:::

::: card title="BxTimeMachine" href="guides/backups.md"
Your setup, your system and your files, backed up to a NAS or the cloud, and one screen to go back through time.
:::

::: card title="Control Center" href="guides/control-center.md"
One terminal for your machine: what needs attention, what runs and how fresh your backups are.
:::

::: card title="Mail catcher" href="guides/mail.md"
A local inbox for the mail your apps send while you develop. One command, nothing leaves your machine.
:::

::: card title="Every app, your choice" href="guides/apps.md"
A curated catalog of 280 apps and web apps, with one-click Google, Microsoft and Apple suites.
:::

::: card title="BoxLang, ready" href="guides/boxlang.md"
BoxLang, MatchBox, their version managers, VS Code with the extension, and modules from ForgeBox.
:::

::: card title="AI agents that know the machine" href="guides/ai.md"
Claude Code, Codex, Gemini and more, with keys in your keyring and skills that teach them BxRig.
:::

## How it behaves

- Nothing changes until you say so: every command prints a plan and needs `--yes`.
- Files you edit are kept. BxRig only rewrites files it wrote itself.
- Everything is also a command, with `--json` output, so you can script it.

---
title: Home
order: 1
summary: Your developer machine, set up in minutes.
---

# BxCachy

**BxCachy** turns a fresh CachyOS install into a finished developer machine: Hyprland with Noctalia (KDE Plasma stays installed beside it), BoxLang and MatchBox, your apps, your shell, your AI agents, all chosen in one guided setup. It is a single native program written in [BoxLang](https://boxlang.io) and compiled with [MatchBox](https://matchbox.boxlang.io).

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

::: card title="Every app, your choice" href="guides/apps.md"
A curated catalog of 280 apps and web apps, with one-click Google, Microsoft and Apple suites.
:::

::: card title="BoxLang, ready" href="guides/boxlang.md"
BoxLang, MatchBox, their version managers, VS Code with the extension, and modules from ForgeBox.
:::

::: card title="AI agents that know the machine" href="guides/ai.md"
Claude Code, Codex, Gemini and more, with keys in your keyring and skills that teach them BxCachy.
:::

## How it behaves

- Nothing changes until you say so: every command prints a plan and needs `--yes`.
- Files you edit are kept. BxCachy only rewrites files it wrote itself.
- Everything is also a command, with `--json` output, so you can script it.

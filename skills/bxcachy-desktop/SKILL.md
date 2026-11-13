---
name: bxcachy-desktop
description: "Use this skill when working with the BxCachy desktop: Hyprland and Noctalia, KDE Plasma panels and tiling, shortcuts and Mac-style keys, screenshots, notifications and Do Not Disturb, night shift, the overview, force quit, emoji, trackpad gestures, or the control center menu."
---

# BxCachy: the desktop

## Two desktops, one command set

- Hyprland + Noctalia is the main desktop (`bxcachy setup hyprland`). KDE Plasma stays installed; `bxcachy setup plasma` adds HyprKwin tiling (`bxcachy tiling on|off|status|layout NAME`).
- Plasma panels: `bxcachy plasma panels apply|undo|status` (top status panel, bottom dock, Panel Colorizer islands; backed up first). `bxcachy plasma desktops N` sets virtual desktops. Workspaces default to 4.

## Shortcuts

- One table drives xremap, Hyprland and Plasma. `bxcachy keys show|sheet|check|conflicts`, `keys set ID COMBO --yes`, `keys reset ID --yes`. Never edit `bxcachy.lua` by hand.
- Cmd-style keys (Super plus Z X A S F T N O P R W L B I U comma) become Ctrl keys in apps; terminals keep shell keys safe. Toggle with `bxcachy keys mac`.
- Useful: `Super+Alt+M` control center, `Super+K` cheat sheet, `Super+Shift+3/4/5` screenshots, `Super+Ctrl+E` emoji, `Super+Alt+Escape` force quit, `Super+Ctrl+Up` overview, `Super+M` minimize.

## Everyday commands

- Screenshots: `screenshot screen|region|window [--edit]`, `screenshot ocr`, `screenshot qr`, `qr TEXT`. Recording: `record toggle [--region]`. Clipboard: `clipboard pick`.
- Notifications: `notify dnd on|off|toggle`, `notify snooze 30m`, `notify clear`. Night shift: `nightshift on|off|toggle`.
- `emoji`, `forcequit`, `window minimize|restore`, `overview`, `input gestures --yes`, `airplay on|off`.
- `bxcachy menu` is the control center; `bxcachy apps` the all-apps window; `bxcachy runner` chooses the launcher and menu program.

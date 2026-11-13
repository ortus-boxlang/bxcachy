---
title: The desktop
order: 2
summary: Hyprland with Noctalia, KDE Plasma with tiling and panels, and the everyday tools around them.
---

# The desktop

BxCachy sets up **Hyprland with Noctalia** as the main desktop. **KDE Plasma** stays installed and gets tiling and a status panel; pick either (or both) at the login screen (`bxcachy session set hyprland|plasma`).

## Hyprland and Noctalia

`bxcachy setup hyprland` installs the packages one by one and writes the starter configuration once. `~/.config/hypr/hyprland.lua` is yours. BxCachy owns `~/.config/hypr/bxcachy.lua`, which it regenerates from the [shortcut table](shortcuts.md); never edit that file by hand.

## KDE Plasma

- **Tiling:** `bxcachy setup plasma` installs HyprKwin. Layouts: dwindle, master, monocle, scrolling, stage. `bxcachy tiling on|off|status|layout NAME`.
- **Panels:** `bxcachy plasma panels apply` replaces your panels with a top status panel (launcher, workspace pager, active window, clock, weather, media, system vitals, tray, in rounded islands with Panel Colorizer) and a bottom dock. Your old layout is backed up first: `bxcachy plasma panels undo --yes` restores it. From Hyprland it is applied at your next Plasma login.
- **Virtual desktops:** `bxcachy plasma desktops 4`.

Look and hardware have their own pages: [Appearance](appearance.md) for the bar, dock, windows and fonts, and [Displays, power and time](system.md) for monitors, laptop power and the time zone. The [control center](menu.md) has all of it as one menu.

## Everyday tools

| Do | Command | Shortcut |
|---|---|---|
| Control center | `bxcachy menu` | `Super+Alt+M` |
| All apps window | `bxcachy apps` | `Super+Alt+Space` |
| Screenshot | `bxcachy screenshot screen\|region\|window` | `Super+Shift+3` / `4` / `5` (menu) |
| Text from the screen | `bxcachy screenshot ocr` | in the `5` menu |
| QR codes | `bxcachy screenshot qr`, `bxcachy qr TEXT` | |
| Record the screen | `bxcachy record toggle [--region]` | `Super+Shift+R` |
| Clipboard history | `bxcachy clipboard pick` | `Super+Shift+V` |
| Do Not Disturb | `bxcachy notify dnd toggle`, `notify snooze 30m` | `Super+Alt+N` |
| Night shift | `bxcachy nightshift on\|off\|toggle` | `Super+Alt+Shift+N` |
| Emoji | `bxcachy emoji` | `Super+Ctrl+E` |
| Force quit | `bxcachy forcequit` | `Super+Alt+Escape` |
| Overview | `bxcachy overview` | `Super+Ctrl+Up` |
| Minimize / restore | `bxcachy window minimize\|restore` | `Super+M` / `Super+Shift+M` |
| Pull-down AI shell | `bxcachy ai shell` | ``Super+` `` |

Night shift on Hyprland runs `wlsunset` with your time zone's sunrise and sunset (no network lookup); on Plasma it turns on Plasma's own Night Light.

## Trackpads and Apple devices

`bxcachy input gestures --yes` sets up three-finger swipes (workspaces, overview) with `libinput-gestures`. `bxcachy input doctor` checks Magic Mouse and Magic Trackpad support (the kernel driver, Bluetooth, the `input` group). For Option-key characters like a Mac, pick the **English (US, Macintosh)** keyboard layout in the wizard. `bxcachy airplay on` starts an AirPlay receiver.

## Hot corners

Hot corners are left to you: on Plasma use System Settings → Screen Edges.

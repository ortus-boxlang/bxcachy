---
title: Shortcuts and Mac keys
order: 3
summary: One table drives xremap, Hyprland and Plasma.
---

# Shortcuts and Mac keys

BxCachy keeps one shortcut table and renders it for xremap (Cmd-style keys, on both desktops), the Hyprland module and Plasma. Press `Super+K` (or run `bxcachy keys sheet`) to see every shortcut in your menu program.

## Cmd-style keys

With Mac keys on, the Super key works like Cmd in apps: `Super+C V X Z A S F T N O P R W L B I U` and `Super+,` send the Ctrl version. In terminals `Super+C/V` copy and paste with `Ctrl+Shift`, `Super+T/N/W/F` become `Ctrl+Shift+T/N/W/F`, and the shell keys (`Ctrl+Z`, `Ctrl+A`...) are left alone. `bxcachy keys mac on|off` toggles it.

## Change a shortcut

```bash
bxcachy keys show                         # the table
bxcachy keys set control-center Super+Alt+C --yes
bxcachy keys reset control-center --yes
bxcachy keys conflicts                    # clashes with your own hyprland.lua
```

Your changes live in `~/.config/bxcachy/shortcuts.json`. Remaps (the Cmd keys) are xremap's and cannot be changed this way.

## The main ones

| Keys | Does |
|---|---|
| `Super+Alt+M` | Control center |
| `Super+Alt+Space` | All apps |
| `Super+K` | Shortcut cheat sheet |
| `Super+Shift+3` / `4` / `5` | Screenshot: screen / region / menu |
| `Super+Shift+R` | Screen recording |
| `Super+Shift+V` | Clipboard history |
| `Super+Ctrl+E` | Emoji |
| `Super+Ctrl+X` | Dictation on or off (Voxtype) |
| `Super+Alt+N` | Do Not Disturb |
| `Super+Q` | Close window |
| `Super+M` / `Super+Shift+M` | Minimize / show minimized |

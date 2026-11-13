---
title: Appearance
order: 3
summary: The bar, dock, windows, animations, fonts and backgrounds, one setting at a time.
---

# Appearance

`bxcachy appearance` changes how the shell and the windows look. Each change acts at once, is remembered, and can be shown first with `--dry-run`. For colors, see [Themes](themes.md).

```bash
bxcachy appearance status
bxcachy appearance bar position bottom      # top, bottom, left, right
bxcachy appearance bar style glassy         # opaque, glassy, clear
bxcachy appearance bar clock iso            # ten clock formats (time-24h, sunday-12h, date-24h, iso ...)
bxcachy appearance bar battery on           # the percentage next to the battery
bxcachy appearance dock mode autohide       # always, autohide, off
bxcachy appearance windows gaps off         # no gaps and no borders
bxcachy appearance windows corners sharp    # theme, rounded, sharp
bxcachy appearance windows opacity glassy   # opaque, glassy
bxcachy appearance animations off
bxcachy appearance layout scrolling         # dwindle, scrolling, floating
bxcachy appearance font list
bxcachy appearance font install cascadia --yes
bxcachy appearance font cascadia            # Noctalia and the terminals follow
bxcachy appearance background random        # or: list, set NAME, next
bxcachy appearance apply                    # push everything you chose again
```

## Where the changes go

- **Noctalia** (bar, dock, clock, battery, font, corner radius) is changed with `noctalia msg config-set`, so your `config.toml` is not edited. Without Noctalia the choice is saved and `appearance apply` pushes it later.
- **Hyprland** window looks (gaps, corners, opacity, animations, layout) are one generated file, `~/.config/bxcachy/theme/look.lua`, loaded by `bxcachy.lua`. BxCachy reloads Hyprland after a change. Your own `hyprland.lua` is never touched.
- **Fonts** come from seven Nerd Fonts. Changing the font also updates the terminal configs BxCachy wrote, but never one you edited (it tells you which).
- **Backgrounds** are read from `~/Pictures/BxCachy`, `~/Pictures` and the current theme's folder.

The menu has all of this under Appearance.

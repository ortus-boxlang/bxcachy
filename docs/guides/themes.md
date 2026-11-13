---
title: Themes
order: 3
summary: Fifteen color themes that follow you into the shell, terminals, btop, window borders and Neovim.
---

# Themes

BxCachy ships 15 color themes in the Omarchy theme format: five of ours and ten taken from Omarchy.

```bash
bxcachy theme list                  # all themes, the current one marked
bxcachy theme set tokyo-night       # apply one now
bxcachy theme next                  # or random
bxcachy theme mode auto             # theme, dark, light or auto
bxcachy theme status
```

Setting a theme acts at once. `--dry-run` shows what would be written without changing anything.

## What changes

| Where | How |
|---|---|
| Noctalia (bar, launcher, panels, notifications) | a generated palette and the light or dark mode |
| Ghostty, kitty, alacritty, foot | generated files that the starter configs include |
| btop | a generated theme file |
| Hyprland window borders | the accent color, read by the managed `bxcachy.lua` |
| Neovim (LazyVim setup) | the matching colorscheme, applied live without a restart |
| KDE Plasma | switches between Breeze Light and Breeze Dark |
| GTK 3 and 4 apps | `~/.config/gtk-4.0/gtk.css` and `gtk-3.0/gtk.css` (libadwaita colors; adw-gtk3 for GTK 3), plus the dark or light preference through gsettings |
| Qt apps | qt6ct and qt5ct color schemes (set the style to qt6ct in your environment) |
| tmux, fzf | `theme/tmux.conf` and `theme/fzf.sh`, with a one-line hint to source them |
| rofi, fuzzel, wofi | a rofi theme (and a `config.rasi` stub when you have none), `fuzzel.ini`, wofi `style.css` |
| Wallpaper | a BxCachy theme brings one of our wallpapers; use `--keep-wallpaper` to skip it |

VS Code is opt-in: `bxcachy theme vscode` shows a plan, `--yes` merges the colors into `workbench.colorCustomizations` of Code, Code - OSS, VSCodium or Cursor (a backup is kept; a settings file with comments is left alone). Not themed: the Starship prompt, browsers and icons. Your own config files are never edited. Terminal configs you wrote yourself need one include line, which `bxcachy theme set` prints.

Bar, dock, windows, fonts and backgrounds are in [Appearance](appearance.md).

## The themes

BxCachy, BxCachy Light, BxCachy Midnight, BxCachy Cyan and BxCachy Forest are ours. From Omarchy: catppuccin, catppuccin-latte, tokyo-night, gruvbox, nord, rose-pine, kanagawa, everforest, matte-black and flexoki-light (MIT, credited in `themes/NOTICE.md`).

## More themes, and your own

`bxcachy theme install https://github.com/someone/omarchy-name-theme` installs an Omarchy-style theme repository (https only). Themes you already have in `~/.config/omarchy/themes` are found automatically. A theme is a folder with `colors.toml`, an optional `neovim.lua` and an optional `backgrounds/` folder:

```bash
bxcachy theme import ~/my-theme --name=mine
bxcachy theme remove mine
```

Both `colors.toml` formats are understood: the named colors of current Omarchy and the older `color0` to `color15` list.

## Neovim

`bxcachy editor lazyvim --yes` installs the LazyVim starter plus the BxCachy layer: transparent background, BoxLang syntax highlighting ([vim-boxlang](https://github.com/ortus-boxlang/vim-boxlang)), no news popups, the neo-tree extra, and live theme following. An existing `~/.config/nvim` is never touched. To add only BoxLang syntax to a LazyVim config you already have: `bxcachy editor boxlang --yes`.

## The BoxLang prompt segment

The starter Starship prompt shows your BoxLang version, like Java, in folders with `.bx`, `.bxs`, `.bxm`, `.cfc`, `.cfm` or `.cfs` files, `box.json` or `Application.bx`. The starter file is written once, so an existing prompt keeps what you have; `bxcachy config diff starship` shows what is new.

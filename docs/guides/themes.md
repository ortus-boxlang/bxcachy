---
title: Themes
order: 3
summary: Fifteen color themes that follow you into the shell, terminals, btop, window borders and Neovim.
---

# Themes

BxRig ships 15 color themes in the Omarchy theme format: five of ours and ten taken from Omarchy.

```bash
bxrig theme list                  # all themes, the current one marked
bxrig theme set tokyo-night       # apply one now
bxrig theme next                  # or random
bxrig theme mode auto             # theme, dark, light or auto
bxrig theme status
```

Setting a theme acts at once. `--dry-run` shows what would be written without changing anything.

## What changes

| Where | How |
|---|---|
| Noctalia (bar, launcher, panels, notifications) | a generated palette and the light or dark mode |
| Ghostty, kitty, alacritty, foot | generated files that the starter configs include |
| btop | a generated theme file |
| Hyprland window borders | the accent color, read by the managed `bxrig.lua` |
| Neovim (LazyVim setup) | the matching colorscheme, applied live without a restart |
| KDE Plasma | switches between Breeze Light and Breeze Dark |
| GTK 3 and 4 apps | `~/.config/gtk-4.0/gtk.css` and `gtk-3.0/gtk.css` (libadwaita colors; adw-gtk3 for GTK 3), plus the dark or light preference through gsettings |
| Qt apps | qt6ct and qt5ct color schemes (set the style to qt6ct in your environment) |
| tmux, fzf | `theme/tmux.conf` and `theme/fzf.sh`, with a one-line hint to source them |
| rofi, fuzzel, wofi | a rofi theme (and a `config.rasi` stub when you have none), `fuzzel.ini`, wofi `style.css` |
| Wallpaper | a BxRig theme brings one of our wallpapers; use `--keep-wallpaper` to skip it |

VS Code is opt-in: `bxrig theme vscode` shows a plan, `--yes` merges the colors into `workbench.colorCustomizations` of Code, Code - OSS, VSCodium or Cursor (a backup is kept; a settings file with comments is left alone). Not themed: the Starship prompt, browsers and icons. Your own config files are never edited. Terminal configs you wrote yourself need one include line, which `bxrig theme set` prints.

Bar, dock, windows, fonts and backgrounds are in [Appearance](appearance.md).

## The themes

BxRig, BxRig Light, BxRig Midnight, BxRig Cyan and BxRig Forest are ours. From Omarchy: catppuccin, catppuccin-latte, tokyo-night, gruvbox, nord, rose-pine, kanagawa, everforest, matte-black and flexoki-light (MIT, credited in `themes/NOTICE.md`).

## More themes, and your own

`bxrig theme install https://github.com/someone/omarchy-name-theme` installs an Omarchy-style theme repository (https only). Themes you already have in `~/.config/omarchy/themes` are found automatically. A theme is a folder with `colors.toml`, an optional `neovim.lua` and an optional `backgrounds/` folder:

```bash
bxrig theme import ~/my-theme --name=mine
bxrig theme remove mine
```

Both `colors.toml` formats are understood: the named colors of current Omarchy and the older `color0` to `color15` list.

## Neovim

`bxrig editor lazyvim --yes` installs the LazyVim starter plus the BxRig layer: transparent background, BoxLang syntax highlighting ([vim-boxlang](https://github.com/ortus-boxlang/vim-boxlang)), no news popups, the neo-tree extra, and live theme following. An existing `~/.config/nvim` is never touched. To add only BoxLang syntax to a LazyVim config you already have: `bxrig editor boxlang --yes`.

## The BoxLang prompt segment

The starter Starship prompt shows your BoxLang version, like Java, in folders with `.bx`, `.bxs`, `.bxm`, `.cfc`, `.cfm` or `.cfs` files, `box.json` or `Application.bx`. The starter file is written once, so an existing prompt keeps what you have; `bxrig config diff starship` shows what is new.

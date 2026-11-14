---
title: Pictures in the terminal
summary: App icons and screenshots in the TUIs, how they are fetched, cached and kept from ever breaking a screen.
---

# Pictures in the terminal

The TUIs can show app icons and screenshots. A picture is never required: when one is missing, slow or broken, BxRig draws a letter tile and carries on.

## Where pictures come from

| Picture | Sources, in order |
|---|---|
| App icon | the installed icon theme and `.desktop` file, the AppStream catalog icons, [Dashboard Icons](https://github.com/homarr-labs/dashboard-icons) (a letter tile when none has it) |
| Screenshot | the AppStream catalog (`archlinux-appstream-data`, optional), downloaded on first view |

Dashboard Icons is Apache-2.0 licensed. The logos in it belong to their owners and are shown only to identify the app. There is no web image search.

## How it is drawn

MatchBox draws PNG, JPEG, GIF and WebP. Terminals that speak the Kitty graphics protocol (Kitty, Ghostty) show the real picture; every other terminal gets half block pixels. `tui.image_support()` reports which. Needs a MatchBox built with `--features bif-tui`.

| Setting | Effect |
|---|---|
| `BXRIG_IMAGES=off` | never draw pictures, only letter tiles |
| `BXRIG_IMAGES=on` | draw even when the terminal is not detected |
| `BXRIG_SHARE_DIR` | where `/usr/share` is looked up (tests) |
| `BXRIG_CACHE_HOME` | replaces the cache folder |

## Safety guarantees

- **Never blocks.** Downloads and the screenshot index scan run in the background. The first call returns nothing and the picture shows on a later redraw.
- **Never throws.** Every call is wrapped; a failure becomes a letter tile.
- **Limits.** https only, 5 s to connect, a time cap and a size cap per download (5 MB by default), the file type is checked by its first bytes (PNG, JPEG, GIF, WebP), files are written to a temporary name and renamed when complete. MatchBox itself refuses files over 20 MB or 12 megapixels.
- **Failures are remembered.** A URL that failed is not tried again for 6 hours, so a bad link cannot be hammered.
- **Bounded disk.** The cache lives in `~/.cache/bxrig/images` and is trimmed to 200 MB, oldest first. Deleting it is always safe.

## For developers

`TuiKit.image( x, y, w, h, path )` draws and answers `true` or `false`. `imageOrTile( x, y, w, h, path, name )` falls back to a coloured tile with the name's first letter. `ImageCache.get( url, kind )` answers a local path or an empty string. `AppIcons.iconFor( name, theme )` and `AppIcons.screenshotsFor( appstreamId )` answer paths the same way.

Tests: `tests/image_cache_test.bxs`, `tests/app_icons_test.bxs` (both start a local server from `tests/image_server.py`) and `tests/tui_kit_test.bxs`.

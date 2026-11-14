---
title: Displays, power and time
order: 4
summary: Monitors, laptop power, the time zone when you travel, DNS, kernels and stay awake.
---

# Displays, power and time

## Displays

```bash
bxrig display list
bxrig display scale DP-2 1.5          # auto or 0.5 to 4
bxrig display rotate DP-2 90
bxrig display mode DP-2 2560x1440@144
bxrig display position DP-2 2880x0
bxrig display mirror on               # the laptop panel on every external monitor
bxrig display laptop off              # refused when no other monitor would be on
bxrig display brightness up           # down, or set 40
bxrig display apply                   # push what is saved again
```

On Hyprland the settings are one generated file, `~/.config/bxrig/theme/monitors.lua`, loaded after your own `hyprland.lua`, and Hyprland reloads. On Plasma they go through `kscreen-doctor`.

## Laptop power

CachyOS does not ship laptop power tools, so BxRig adds them.

```bash
bxrig power status
bxrig power setup --yes               # power-profiles-daemon and upower; nothing happens on a desktop
bxrig power profile saver             # performance, balanced, saver
bxrig power lid lock --yes            # suspend, lock or ignore when the lid closes
bxrig power doctor                    # daemons, the lid, zram, swap for hibernation
```

The lid setting is a logind drop-in and applies from the next login. Hibernation is not configured for you; `doctor` tells you whether your swap is big enough.

## Time zone and travel

```bash
bxrig time status
bxrig time zone Europe/Madrid --yes   # set it (bxrig time zone --list shows them all)
bxrig time sync --yes                 # after you land: set the zone from your IP address
bxrig time auto on --yes              # or follow your location by itself
bxrig time ntp on --yes
```

`time auto on` installs GeoClue and `automatic-timezoned`, writes the service and the GeoClue settings it needs, and enables it. **GeoClue looks your location up online (the Wi-Fi networks around you or your IP address)**, so the plan says so before you agree. `time auto off` removes everything it wrote. If the zone does not follow you, read `journalctl -u automatic-timezoned`.

## DNS, kernels and stay awake

```bash
bxrig dns                              # the servers in use
bxrig dns cloudflare --yes             # google, quad9, custom 9.9.9.10, dhcp
bxrig kernel list
bxrig kernel install linux-cachyos-lts --yes
bxrig toggle stay-awake                # keep the screen from idling (Noctalia)
```

`dns` changes the active NetworkManager connections. `kernel` installs or removes kernel packages with their headers; it never edits the bootloader, never removes the running or the last kernel, and you pick the kernel in the boot menu. Stay awake needs Noctalia (Hyprland); on Plasma use System Settings.

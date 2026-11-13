---
title: Displays, power and time
order: 4
summary: Monitors, laptop power, the time zone when you travel, DNS, kernels and stay awake.
---

# Displays, power and time

## Displays

```bash
bxcachy display list
bxcachy display scale DP-2 1.5          # auto or 0.5 to 4
bxcachy display rotate DP-2 90
bxcachy display mode DP-2 2560x1440@144
bxcachy display position DP-2 2880x0
bxcachy display mirror on               # the laptop panel on every external monitor
bxcachy display laptop off              # refused when no other monitor would be on
bxcachy display brightness up           # down, or set 40
bxcachy display apply                   # push what is saved again
```

On Hyprland the settings are one generated file, `~/.config/bxcachy/theme/monitors.lua`, loaded after your own `hyprland.lua`, and Hyprland reloads. On Plasma they go through `kscreen-doctor`.

## Laptop power

CachyOS does not ship laptop power tools, so BxCachy adds them.

```bash
bxcachy power status
bxcachy power setup --yes               # power-profiles-daemon and upower; nothing happens on a desktop
bxcachy power profile saver             # performance, balanced, saver
bxcachy power lid lock --yes            # suspend, lock or ignore when the lid closes
bxcachy power doctor                    # daemons, the lid, zram, swap for hibernation
```

The lid setting is a logind drop-in and applies from the next login. Hibernation is not configured for you; `doctor` tells you whether your swap is big enough.

## Time zone and travel

```bash
bxcachy time status
bxcachy time zone Europe/Madrid --yes   # set it (bxcachy time zone --list shows them all)
bxcachy time sync --yes                 # after you land: set the zone from your IP address
bxcachy time auto on --yes              # or follow your location by itself
bxcachy time ntp on --yes
```

`time auto on` installs GeoClue and `automatic-timezoned`, writes the service and the GeoClue settings it needs, and enables it. **GeoClue looks your location up online (the Wi-Fi networks around you or your IP address)**, so the plan says so before you agree. `time auto off` removes everything it wrote. If the zone does not follow you, read `journalctl -u automatic-timezoned`.

## DNS, kernels and stay awake

```bash
bxcachy dns                              # the servers in use
bxcachy dns cloudflare --yes             # google, quad9, custom 9.9.9.10, dhcp
bxcachy kernel list
bxcachy kernel install linux-cachyos-lts --yes
bxcachy toggle stay-awake                # keep the screen from idling (Noctalia)
```

`dns` changes the active NetworkManager connections. `kernel` installs or removes kernel packages with their headers; it never edits the bootloader, never removes the running or the last kernel, and you pick the kernel in the boot menu. Stay awake needs Noctalia (Hyprland); on Plasma use System Settings.

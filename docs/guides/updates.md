---
title: Updates and channels
order: 7
summary: Stable and beta channels, update checks, notifications, and system updates.
---

# Updates and channels

## Channels

| Channel | What it is |
|---|---|
| `stable` | Tagged releases |
| `beta` | The bleeding edge: a build of every push to `development` |

```bash
bxcachy update channel            # show
bxcachy update channel beta       # switch
```

Both are also in the control center (Settings → Updates).

## Update BxCachy

```bash
bxcachy update check              # exit 10 means an update is available
bxcachy update apply --yes        # download, verify, replace atomically
```

The release information is signed (Ed25519) and the binary's SHA-256 is checked against it; a bad signature or checksum changes nothing.

## Get told about updates

```bash
bxcachy update notifications on     # a daily user timer shows a desktop notification
bxcachy update notifications off
```

The notification covers BxCachy and pending system packages.

## Update the system

```bash
bxcachy system update --yes       # snapshot first (snapper or timeshift), then pacman -Syu and yay -Sua
```

## Agent skills

`bxcachy skills update --yes` refreshes the skills BxCachy installed.

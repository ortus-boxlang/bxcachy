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
bxrig update channel            # show
bxrig update channel beta       # switch
```

Both are also in the control center (Settings → Updates).

## Update BxRig

```bash
bxrig update check              # exit 10 means an update is available
bxrig update apply --yes        # download, verify, replace atomically
```

The release information is signed (Ed25519) and the binary's SHA-256 is checked against it; a bad signature or checksum changes nothing.

## Get told about updates

```bash
bxrig update notifications on     # a daily user timer shows a desktop notification
bxrig update notifications off
```

The notification covers BxRig and pending system packages.

## Update the system

```bash
bxrig system update --yes       # snapshot first (snapper or timeshift), then pacman -Syu and yay -Sua
```

## Agent skills

`bxrig skills update --yes` refreshes the skills BxRig installed.

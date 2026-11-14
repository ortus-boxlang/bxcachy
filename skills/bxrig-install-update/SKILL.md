---
name: bxrig-install-update
description: "Use this skill when installing BxRig, running it without human input, choosing the stable or beta update channel, updating BxRig or the system, turning update notifications on or off, or moving settings to another machine."
---

# BxRig: install, update, move

## Install

```bash
curl -fsSL https://downloads.ortussolutions.com/ortussolutions/bxrig/install.sh | bash
```

It checks the machine (CachyOS or Arch, normal user, sudo), downloads the binary and the install bundle for the channel, verifies the signature of the release information and the SHA-256 of both files, runs the stages (packages, toolchains, binary, core apps) and then the wizard.

No human input: `... | bash -s -- --yes [--answers answers.json] [--channel stable|beta] [--no-wizard]`. `--yes` needs passwordless sudo. Without `--answers` the wizard's default answers are applied (`bxrig init --defaults --yes`).

## Update

- `bxrig update check [--notify]`: exit 10 means an update is available. `bxrig update apply --yes` replaces the binary after verifying it.
- Channels: `bxrig update channel stable|beta`. stable is tagged releases; beta is a build of every push to development (bleeding edge).
- `bxrig update notifications on|off|status`: a daily user timer that shows a desktop notification.
- `bxrig system update --yes`: snapshot first (snapper or timeshift), then `pacman -Syu` and `yay -Sua`.

## Move to another machine

- `bxrig settings export FILE.tar.gz` and `bxrig settings import FILE.tar.gz --yes` (secrets are not included: `bxrig secrets export`).
- `bxrig init --export=FILE` and `bxrig init --from=FILE` move only the wizard answers.

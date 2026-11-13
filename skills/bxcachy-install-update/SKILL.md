---
name: bxcachy-install-update
description: "Use this skill when installing BxCachy, running it without human input, choosing the stable or beta update channel, updating BxCachy or the system, turning update notifications on or off, or moving settings to another machine."
---

# BxCachy: install, update, move

## Install

```bash
curl -fsSL https://downloads.ortussolutions.com/ortussolutions/bxcachy/install.sh | bash
```

It checks the machine (CachyOS or Arch, normal user, sudo), downloads the binary and the install bundle for the channel, verifies the signature of the release information and the SHA-256 of both files, runs the stages (packages, toolchains, binary, core apps) and then the wizard.

No human input: `... | bash -s -- --yes [--answers answers.json] [--channel stable|beta] [--no-wizard]`. `--yes` needs passwordless sudo. Without `--answers` the wizard's default answers are applied (`bxcachy init --defaults --yes`).

## Update

- `bxcachy update check [--notify]`: exit 10 means an update is available. `bxcachy update apply --yes` replaces the binary after verifying it.
- Channels: `bxcachy update channel stable|beta`. stable is tagged releases; beta is a build of every push to development (bleeding edge).
- `bxcachy update notifications on|off|status`: a daily user timer that shows a desktop notification.
- `bxcachy system update --yes`: snapshot first (snapper or timeshift), then `pacman -Syu` and `yay -Sua`.

## Move to another machine

- `bxcachy settings export FILE.tar.gz` and `bxcachy settings import FILE.tar.gz --yes` (secrets are not included: `bxcachy secrets export`).
- `bxcachy init --export=FILE` and `bxcachy init --from=FILE` move only the wizard answers.

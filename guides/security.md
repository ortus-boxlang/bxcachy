---
title: Security
order: 9
summary: What the installer and updater verify, and where secrets live.
---

# Security

- **Releases are signed.** CI signs each channel's `version-latest.properties` and `install.sh` with an Ed25519 key. The public key is built into the program and into the published installer. The installer and `bxcachy update` verify the signature and the SHA-256 of every file they download; any mismatch stops before anything changes.
- **The first `curl | bash`** trusts the script it downloads (TLS and the bucket). For a stricter first install, download `install.sh` and `install.sh.sig` and check the signature yourself with `keys/release.pub`.
- **Nothing runs without a plan.** Commands that change the system print a plan and need `--yes`.
- **Your files are yours.** BxCachy keeps a config you changed and only rewrites files it wrote; every write is atomic, backed up and journaled.
- **Secrets** live in the desktop keyring (or a private file fallback), are typed hidden, and never appear in answers files, logs or shell history.
- **Skills** from the hub are audited; one that failed its audit is refused.

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

## Fingerprint, security key, SSH and passwordless sudo

`bxcachy security` can turn on a fingerprint or a security key for `sudo`, the SSH server and passwordless sudo. These touch PAM and sudoers, so they are guarded.

```bash
bxcachy security status
bxcachy security fingerprint on --dry-run   # prints the exact PAM line first
bxcachy security fingerprint on --yes
bxcachy security fingerprint enroll --yes
bxcachy security fido2 register --yes       # touch the key; `fido2 on` refuses until one is registered
bxcachy security fido2 on --yes
bxcachy security ssh-server on --yes
bxcachy security passwordless-sudo on --yes
```

- **Only `/etc/pam.d/sudo` is changed**, never the login, the login screen or the lock screen. The line is `auth sufficient`, so your password still works when the reader or key is missing. The first time, the original is kept as `/etc/pam.d/sudo.bxcachy-backup`; `off` removes exactly the line BxCachy added.
- **sudoers** is checked with `visudo -cf` before the file is installed, so a mistake cannot lock sudo out.
- **Passwordless sudo** means any program running as you gets root without a password. Use it only on a machine where you accept that.
- Keep a root terminal open the first time you try PAM changes. They have not been tried on a real reader or key yet.


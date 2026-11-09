# BxCachy v0.10.0 — integration hardening

- Dolphin Quick Look installs Qt/PySide6 dependencies and service menu automatically via `bxcachy integrations quicklook`. Dolphin does not expose a reliable built-in Spacebar preview API; the context-menu action is the supported integration. No unsafe global Space interception is installed.
- Hyprland dictation shortcut template is included automatically when `bxcachy integrations shortcuts` runs, but binding activation is deliberately opt-in because Alt+Space may collide with existing shortcuts. Superwhisper/Voxtype executable command compatibility must be established on the target machine before claiming universal dictation.
- Cloud services generate idempotent per-user systemd units; existing modified units are never overwritten. `bxcachy cloud-services install REMOTE --yes` uses a previously authenticated rclone remote. rclone mount is not offline synchronization.
- Full desktop integration and actual voice/cloud authentication require the target Wayland session and account; they cannot be demonstrated in a headless container.
- The Quasar/Tauri unified Control Center remains deferred.

# BxCachy v0.9.9 — integrations

## Defaults
- Dolphin, KDE plugins, rclone, fuse3, sshfs, and Google Drive web app.
- BxCachy Cloud Center with opt-in per-remote systemd user auto-mounts (Google Drive, Dropbox, S3, WebDAV).
- Superwhisper selected as preferred dictation provider (package installation is explicitly authorized with `bxcachy dictation select superwhisper --yes`; commercial/cloud service terms apply).
- Quick Look Qt viewer and Dolphin service menu: `bxcachy integrations quicklook`. The file action is installed, but Space-to-preview from Dolphin file selection is not available via an established KDE plugin API.

## Optional
- Voxtype: `bxcachy dictation select voxtype --yes` (local/offline).
- Insync: commercial full offline Google Drive/Dropbox synchronization, not equivalent to rclone mount.
- Dropbox official desktop sync, kio-gdrive experimental, rclone-browser, S3 GUI Brows3 (package availability dependent).
- rclone cloud mounts expose filesystem access, **not offline sync**.

## Setup
`bxcachy integrations quicklook` installs the Dolphin context menu and launcher in user paths without replacing existing files.
`bxcachy integrations shortcuts` creates a commented Hyprland template; bindings require user opt-in to avoid clobbering existing shortcuts.
`bxcachy cloud configure` configures remote accounts with rclone.
`bxcachy cloud-services install myremote --yes` enables a per-user systemd mount with automatic restart; `remove` disables it.

## Limits
Superwhisper/Voxtype CLI and Arch packaging require validation on a real CachyOS host. No native Dolphin Space key binding is claimed. No graphical S3 bucket management beyond rclone remote/mount support is claimed.

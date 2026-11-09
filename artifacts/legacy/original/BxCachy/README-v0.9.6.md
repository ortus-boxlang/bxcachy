# BxCachy v0.9.6 — Cloud & File Manager Integration

## Decisions applied
- Dolphin remains the default file manager. The KDE extension/thumbnail/network pack is selected for installation.
- Google Drive web app remains a default. `rclone` + `fuse3` are default packages, but authentication and mounting are **opt-in**.
- Insync (commercial full Google Drive/Dropbox synchronization), official Dropbox via AUR, Rclone Browser, and experimental `kio-gdrive` remain optional.
- Flea and Strata are optional, *manual/unverified* catalog candidates. No system file manager or shortcuts are replaced.
- Tabby is selected by default. Beekeeper Studio and Podman Desktop remain defaults; DBeaver, DataGrip and Redis Insight remain optional.
- Existing BxCachy web app creator and database control center are retained. Vector database support remains planned, not implemented.

## Cloud setup
```
./bin/bxcachy cloud doctor
./bin/bxcachy cloud configure  # interactive rclone OAuth; user initiates
./bin/bxcachy cloud remotes
./bin/bxcachy cloud mount gdrive  # plan only
./bin/bxcachy cloud mount gdrive --yes
./bin/bxcachy cloud unmount gdrive --yes
./bin/bxcachy files doctor
./bin/bxcachy files preview-help
```
`rclone mount` uses VFS caching and `--daemon`; requires FUSE and a functioning session. It does not create persistent systemd services. Do not confuse mounts with offline sync. `kio-gdrive` OAuth may not work. Dropbox and Insync tray overlays must be tested under Wayland/Plasma.

## Remaining implementation/validation backlog
- Live CachyOS/Hyprland testing, KIO Google OAuth, tray icons, Dolphin Dropbox overlays, Insync licensing, and actual cloud OAuth/mount tests.
- Mac-style floating Quick Look for Dolphin: no safe standard plugin verified; do not patch system Dolphin. Evaluate Flea/Strata live.
- Vector databases (pgvector, Qdrant, Milvus, Weaviate, Chroma), Derby/SQLite database workflows, and backup/restore in db-center.
- Global dictation, network diagnostic GUI, complete web app menu integration, database GUI deep linking, Podman Desktop and Lazydocker real-world validation.

# BxCachy v0.9.5 — developer workstation catalog and control centers

- Beekeeper Studio default; DBeaver/DataGrip optional; Redis Insight optional.
- Podman Desktop default (AUR mapping unverified); Lazydocker default, Podman TUI optional.
- Google Drive/Docs/Sheets/Slides web shortcuts default. Google Drive is **not** a filesystem mount.
- Official Dropbox client optional; Insync and Rclone Browser optional; rclone CLI default.
- S3 GUI Brows3 optional pending packaging verification. FileZilla optional; muCommander alternative.
- Dictation candidate OpenWhispr optional pending CachyOS/Hyprland verification; no shortcut overwritten.
- `bxcachy web "My App" https://example.com --yes` creates a user web-app launcher.
- `bxcachy db-center` opens a graphical database control center using the configured menu runner; requires Podman for operations.
- No AUR install or real remote session was run in the build environment.
- Future database roadmap: pgvector Postgres, Qdrant, Milvus, Weaviate, Chroma; Apache Derby via JDBC client, not Beekeeper.

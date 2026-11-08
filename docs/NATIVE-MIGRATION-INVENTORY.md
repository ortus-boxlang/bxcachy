# Native migration inventory (v0.10.0)

The legacy archive contains 45+ executable entrypoints and 20+ test files. The new BoxLang CLI currently does **not** provide feature parity.

## Required workstreams

1. Installer, provisioning, first-run, menus and profiles.
2. App catalog, package manager, developer tools and extras.
3. KDE Plasma desktop, themes, icons, keyboard shortcuts and Omarchy-style tools.
4. AI, vector DB, database, VM, Podman and networking.
5. Cloud storage, cloud services and cloud center (rclone/FUSE).
6. Quick Look (Dolphin integration), dictation and system integration.
7. Native MatchBox build, Rust/Cargo fusion where necessary, TestBox and Arch integration CI.

## Acceptance gates

- Every existing v0.10.0 command has an equivalent native implementation or an explicitly documented replacement.
- No Python runtime is required for production commands.
- Java 21, BVM, MVM are installed by the workstation bootstrap; versions are pinned.
- MatchBox produces an executable artifact and smoke tests run against that artifact.
- CI validates package operations safely in Arch, and desktop integration in a compatible environment.
- The migration is **not complete** until those checks pass.

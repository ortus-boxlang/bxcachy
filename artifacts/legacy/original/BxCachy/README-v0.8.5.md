# BxCachy v0.8.5 (development)

Preserves existing CachyOS, KDE, Hyprland, Noctalia and user configurations.

- `./bin/bxcachy first-run plan|install --yes|doctor` — staged base setup and failure summary; existing base installers still request explicit upstream script confirmation.
- `./bin/bxcachy desktop-keys plan|stage` — opt-in Hyprland keybind file; never sourced automatically. Check conflicts with Noctalia before enabling.
- `./bin/bxcachy system snapshot-configure` — read-only inspection; manual filesystem-specific root configuration remains required.
- `./bin/bxcachy system update --yes` — fail-closed pre-update snapshot attempt, `--no-snapshot` explicit override.
- `./bin/bxcachy apps desktop-list|tui-list|web-list` — category catalogs; optional apps remain optional.
- `./bin/bxcachy podman doctor` and `./bin/bxcachy extras doctor docker-aliases` — rootless / Docker wrapper checks. Socket activation remains opt-in.

**Not validated on CachyOS.** Snapshot rollback is deliberately not automated, because bootloader and Btrfs layout vary. Desktop shortcuts are staged, not activated. The catalogs list web destinations rather than creating desktop launchers.

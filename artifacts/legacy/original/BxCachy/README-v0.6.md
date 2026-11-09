# BxCachy v0.6 — four-phase integration

1. **Windows VM:** `bin/bxcachy vm plan|doctor|install|start|stop|restart|status|logs|remove`. Rootless Podman, KVM required. Container removal preserves disk. Default RDP and web ports bound to localhost. Windows licensing and Dockur image compatibility must be reviewed.
2. **Configuration:** `bin/bxcachy config plan|doctor|activate|rollback SNAPSHOT`. Only traditional Hyprland `hyprland.conf` activation supported; Lua configs require manual integration. No KDE edits. Generate shortcuts first; inspect conflicts before activation.
3. **Install catalog:** `bin/bxcachy catalog list|validate|plan ID|install ID`. User overrides in `~/.config/bxcachy/installers.json`; review remote scripts before executing. Pacman-first installers remain in `bin/bxcachy-dev`.
4. **Tests:** `python -m unittest discover -s tests -v`; shell syntax check via `bash -n`. Live CachyOS, Noctalia, GPU/KVM, VM boot, and SDKMAN/BoxLang downloads require real machine validation.

## Known limits
- Existing `provision` code is legacy and still uses its previous state directory.
- Full Noctalia/theme sync, desktop-wide shortcut conflict detection, GUI editing, and rollback of package transactions remain incomplete.
- Dockur's Podman compatibility varies by host security configuration. VM may require extra permissions; do not expose default ports publicly.
- The installer catalog is extendable but does not yet manage version pinning or upgrades.

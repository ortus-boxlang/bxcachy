# BxCachy catalog

`apps.json` is the app catalog (schema 2, draft 0.1.0). It replaces the legacy v0.10.0 `catalog/apps.json` (kept unmodified under `artifacts/legacy/original/`).

- `tier`: `default` (installed by a plain install) or `optional` (offered in the picker). Apps that are not listed are not part of the catalog.
- `source`: `pacman` (official or CachyOS repo), `aur`, `pkgbuild` (build from a public PKGBUILD with `makepkg` as the normal user), `web` (frameless web app, `url`), `unresolved` (no installable package found yet).
- `targets`: package names for `pacman`, `aur`, `pkgbuild` and `unresolved`.
- `origin`: why the entry exists (`owner-pick`, `omarchy-desktop`, `omarchy-web`, `omarchy-shell-tool`, `gaming`, `owner-request`).
- `macos`: suggested macOS equivalent. A suggestion, not a verified mapping.
- `verified_on`: date the package target was resolved against the CachyOS repos (cachyos, v3, v4), Arch (core, extra, multilib) and the AUR.

Status: draft for testing. `pkgbuild.ref` is `master` and must be pinned to a commit before an installer uses it. The Omarchy app inventory comes from the unofficial store omarchyapps.com and the Omarchy 4.5 notes. Curation continues after testing.

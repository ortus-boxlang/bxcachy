# BxCachy catalog

`apps.json` is the app catalog (schema 3, draft 0.2.0). It replaces the legacy v0.10.0 `catalog/apps.json` (kept unmodified under `artifacts/legacy/original/`).

- `tier`: `default` (installed by a plain install) or `optional` (offered in the picker). Apps that are not listed are not part of the catalog.
- `source`: `pacman` (official or CachyOS repo), `aur`, `pkgbuild` (build from a public PKGBUILD with `makepkg` as the normal user), `npm` (global npm package installed through nvm: `targets` has the one package name, `bin` the command it installs), `web` (frameless web app, `url`), `unresolved` (no installable package found yet).
- `targets`: package names for `pacman`, `aur`, `pkgbuild` and `unresolved`.
- `origin`: why the entry exists (`owner-pick`, `omarchy-desktop`, `omarchy-web`, `omarchy-shell-tool`, `gaming`, `owner-request`).
- `macos`: suggested macOS equivalent. A suggestion, not a verified mapping.
- `verified_on`: date the package target was resolved against the CachyOS repos (cachyos, v3, v4), Arch (core, extra, multilib) and the AUR.

Status: draft for testing. `pkgbuild.ref` is `master` and must be pinned to a commit before an installer uses it. The Omarchy app inventory comes from the unofficial store omarchyapps.com and the Omarchy 4.5 notes. Curation continues after testing.

## Schema 3 (presentation metadata)

- `groups`: ordered top-level sections (`id`, `title`, `blurb`, `order`). `categories`: ordered sub-sections (`group`, `title`, `order`). Every app's `group` is a group `id` and its `category` is a category `title` of that group. Apps are stored sorted by group, category, default tier first, then name.
- `description`: one line for a picker. `description_source` says where it came from: `arch` (official package description), `aur` (AUR description), `pkgbuild` (the `pkgdesc` of the Omarchy PKGBUILD) or `curated` (written by hand: web apps, multi-package entries, unresolved entries).
- `homepage`: upstream URL from the same package metadata, or the web app URL.
- `macos`: macOS equivalent or "(same)" when the app exists on macOS, `null` when there is no useful mapping.
- Found while enriching: the AUR package `hype` is a Twitch tool, not the Omarchy presentation app, so `hype` is now `unresolved`.

## Profiles and shells (0.3.0)

- `profiles`: ordered top-level list (`id`, `title`, `blurb`, `order`), like `groups`. An app joins profiles through `profiles`, a map of profile id to `default` or `optional` for that profile: `{ "jq": { "core": "default", "terminal": "optional" } }`. `install --profile=NAME` installs the `default` members; `--optional` adds the `optional` ones. An app's own `tier` still decides a plain `install`. Every profile needs at least one `default` member.
- `shells`: optional list of `hyprland` and/or `plasma`. No `shells` means the app installs under either desktop. An app that does not match the running shell is skipped with `wrong_shell`, unless it is named explicitly. Hyprland-only entries today: hyprsunset, hyprpicker, wayfreeze, walker, owe, aether (hyprpicker, wayfreeze and walker are unverified on Plasma).

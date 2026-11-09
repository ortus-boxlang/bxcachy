# BxCachy command contract (A5 draft, v3)

Target (2026-11-09): Hyprland + Noctalia on CachyOS, KDE kept side by side; see plan.md section 19. `setup` is the headline command.

Status: **proposal, no code written.** Note 2026-11-09: the legacy tree in `artifacts/legacy/original/` is the real v0.10.0 source. It is kept as is and never copied, backed up or modified. Decisions here are inputs to M0 hardening (tasks 1.2 to 1.5) and M1 catalog work. Legacy v0.10.0 is a feature reference only (`artifacts/legacy/original/`).

## 1. Grammar

```
bxcachy <group> <verb> [args...] [--yes] [--dry-run] [--json] [--quiet]
```

- Groups mirror the legacy dispatcher so users keep their muscle memory: `setup apps app-manager catalog profile base extras dev web podman ai vector db db-center vm network cloud cloud-center cloud-services files quicklook dictation integrations desktop desktop-keys mac-keys omarchy-base layout themes icons runner menu shortcuts system config first-run doctor setup`.
- Global verbs on every group: `plan` (read-only), `status` (read-only), `doctor` (read-only checks), `help`.
- Mutating verbs: `install`, `apply`, `remove`, `restore`, `enable`, `disable`. All require `--yes`.
- Existing flat commands (`install`, `optional-install`, `profile-install`, `package-status`, `package-source`, ...) stay as aliases until the grouped form ships, then print a deprecation note.
- Unknown flags, duplicate flags, empty arguments and extra positionals are usage errors (exit 2). Nothing runs.
- Note from M0 history: BoxLang `CLIGetArgs()` puts flags in `args.options`, not `args.positionals`. The parser is one shared function, tested once.

## 2. Mutation rules (apply to every mutating verb)

1. No `--yes`: print the exact plan, change nothing, exit 2.
2. `--dry-run` with `--yes`: print the exact plan, change nothing, exit 0.
3. Preflight everything before the first mutation. A preflight failure means zero changes.
4. Never escalate privilege silently. `sudo` is only called for pacman steps shown in the plan.
5. Never run AUR builds as root (exit 4).
6. Every config file touched goes through the config service (backup, atomic replace, journal). No direct writes.
7. Output lists succeeded and failed items separately. No rollback is promised across pacman and yay.
8. External scripts (catalog `source: script`) are downloaded to a temp file, shown to the user, and run as the normal user (never root) only after a typed `EXECUTE` confirmation. No curl-to-shell. Decision 2026-11-09: no checksum pinning for these scripts.
9. Subprocesses are launched with argument arrays, never through a shell string.

## 3. Exit codes

| Code | Meaning | Example |
|---|---|---|
| 0 | Success or no-op | already installed, or `--dry-run` |
| 1 | Check negative | `package-status` says missing |
| 2 | Usage error or missing confirmation | no `--yes`, unknown flag |
| 3 | Timeout, or item unavailable | pacman lookup timed out, package not in any repo |
| 4 | Precondition failed | root with AUR, not Arch, Java missing, not KDE where required |
| 5 | Official (pacman) phase failed | |
| 6 | AUR (yay) phase failed | |
| 7 | Partial success | some items done, some failed; `--json` lists both |
| 8 | Config conflict | drift detected, symlink or special file at target, concurrent run lock |
| 9 | Internal error | bug, unexpected exception |

Codes 0 to 6 match what the native CLI returns today (2, 3, 4, 5, 6 are already used). 1 is already used for check-negative. 7 to 9 are new. Codes are frozen once published and covered by a contract snapshot test.

## 4. `--json`

One JSON object on stdout, nothing else on stdout. Human text goes to stderr.

```json
{
  "schema": 1,
  "command": "profile install",
  "version": "0.11.0-dev",
  "ok": false,
  "exit": 7,
  "dry_run": false,
  "plan":    [{"id": "jq", "source": "pacman", "action": "install"}],
  "done":    [{"id": "jq", "source": "pacman"}],
  "failed":  [{"id": "x", "source": "aur", "reason": "yay exited 1"}],
  "skipped": [{"id": "git", "reason": "already installed"}],
  "warnings": []
}
```

Read-only commands use the same envelope with a `data` field.

## 5. Catalog (single source of truth)

Decision already made: import legacy `catalog/apps.json` (482 entries) as canonical, keeping its 61 default flags. It replaces the hardcoded lists in `src/bxcachy.bxs` and `scripts/package-manager.sh`.

Entry schema (legacy fields kept, new fields marked):

| Field | Notes |
|---|---|
| `id`, `name`, `kind` (`desktop` `tui` `web`), `category`, `description` | as legacy |
| `source` (`pacman` `aur` `pkgbuild` `script` `manual` `web`), `target` | package name, or URL for web and script |
| `pkgbuild` source: `repo`, `path`, `ref` | Build with `makepkg` as the normal user from a PKGBUILD in a public git repo, pinned to a full 40-character commit (`catalog check` rejects anything else), then install the result with pacman. Used for Omarchy 4.5 apps (`omacom/omarchy-pkgs`). The PKGBUILD is shown before it is built. |
| `check` (for `script`) | argv array that exits 0 when installed, for example `["command","-v","pi"]` |
| `default` | base tier flag |
| `source_status`, `source_confirmed` | legacy provenance flags, kept |
| `profiles` (new) | list of profile ids |
| `deps` (new) | other catalog ids |
| `check` (new) | optional post-install check, argv array |
| `verified_on` (new) | date the target was confirmed against real repos |

Findings from the legacy data (decisions recorded 2026-11-09):

- **Unverified sources.** 176 entries are `source: manual` (95 tui, 81 desktop). Their package names are unverified. Proposal: a CI job that checks every `pacman`/`aur` target against real repos (Arch container, AUR RPC) and fails on unknown names. `manual` entries stay installable only by explicit user action.
- **Default list mismatch.** 61 flagged default (29 pacman, 18 aur, 14 web). `app-profile.json` `base` lists 46. 20 defaults are not in that base list (for example `ark dolphin dolphin-plugins kio-extras rclone fuse3 sshfs nfs-utils cifs-utils podman-desktop tabby beekeeper-studio google-docs google-sheets google-slides kompare filelight ffmpegthumbs kdegraphics-thumbnailers kimageformats`). 5 base entries are not flagged default (`dbeaver filezilla krdc podman-tui rustdesk`). The 61 flags win. The 5 dropped base entries are `dbeaver` (pacman), `filezilla` (pacman), `krdc` (pacman), `rustdesk` (aur) and `podman-tui` (manual). Pending: keep them as curated (not default), or re-flag any as default.
- **Browsers.** `brave` is `aur` (`brave-bin`) and default. A fresh default install therefore needs yay on day one. Decision: bootstrap installs yay only if it is not already present.
- **Preserve list.** Legacy `preserve` (CachyOS, KDE Plasma, Hyprland, Noctalia, existing user configs) becomes enforced rules, not just text.

Named profiles keep the existing four (`core jvm containers terminal`) and are expressed as catalog `profiles` tags. Later profiles (`web backend ai ops desktop full`) are added only after package names are verified.

Ship vs embed (pending confirmation): the default catalog is embedded in the binary at build time, so there is one file to ship and it always matches the code. An optional `~/.config/bxcachy/catalog.json` adds entries or sets `default`/`profiles` on existing ids. It is validated against the same schema and can never delete or replace an embedded entry's `target`, so a bad override cannot redirect an install.

## 6. State and config layout

```
~/.config/bxcachy/            same root as legacy
  bxcachy.json                global settings
  catalog.json                optional user additions (merge-only)
  ai.json menu.json shortcuts.json ...   one file per feature, as legacy
~/.local/state/bxcachy/
  journal/                    one record per apply: files, hashes, backup paths
  backups/                    backups, indexed by the journal
  lock                        single-writer lock
```

`config list|diff|apply|restore` work from the journal, so restore needs only an id. Retention default: keep the last 20 per file. Open: this applies to the user's config files that BxCachy writes, not to the legacy source tree.

## 7. Test contract

- A snapshot test freezes `bxcachy help`, the exit-code table and the `--json` schema.
- Every mutating verb needs these cases: success, no-op, invalid input, dependency failure, privilege rejection, partial failure, recovery.
- Real-system cases run in `tests/arch/` (non-root, real pacman). Cases needing KDE, Wayland or hardware are marked `manual` and tracked in the acceptance log.

## 8. Catalog check, validation and reporting

`bxcachy catalog check [--json] [--online]` plus a CI job that runs it in the Arch container.

**Offline validation (always, no network):** schema version; unique ids; enums for `kind`/`source`; `web` targets are https with no credentials or control characters; package targets match `^[a-zA-Z0-9@._+-]+$`; `default` entries have a non-`manual` source; `profiles` and `deps` reference existing ids; no dependency cycles.

**Online verification (`--online`, CI):** every `pacman` target must resolve with `pacman -Si` (or `-Sg` for groups); every `aur` target must resolve through the AUR RPC (`/rpc/v5/info`); `manual` targets are probed against both and reported as promotable. Results are stored per entry as `verified_on` and a status: `ok`, `moved` (listed source is wrong but another source has it), `missing`, `unverified`.

**Reporting:** a table by status and source for the console, `--json` for tools, and a markdown report in the CI step summary and artifact. Policy: `missing` entries with `default: true` fail CI; `missing` non-default entries are warnings listed in the report; `moved` entries are warnings with the suggested fix.

**First measurement (2026-11-09, stock Arch core/extra only, so CachyOS repos and multilib are not covered):**

| Check | Result |
|---|---|
| `pacman` targets (118) | 111 resolve, 7 do not: 5 exist in AUR (`git-cola insomnia localsend ulauncher wlogout`), 2 found nowhere (`intellij-idea-community-edition`, `swww`) |
| `aur` targets (64) | 40 resolve in AUR, 11 are now official (`doggo impala nwg-dock-hyprland opencode podman-desktop rio spotify-launcher superfile television warehouse zenmap`), 13 found nowhere (`beeper ctop dbgate espanso grokbot herder inshellisense notion-desktop pi-agent tmog todoist upnote zap-whatsapp`) |
| `manual` targets (176) | 93 are official packages today (promotable, for example `jq ripgrep-all tmux kitty starship terraform kubectl`), 83 are not |

The check must also run against the CachyOS repos on a real CachyOS machine before any `missing` entry is removed.

## 9. Open questions

1. The 5 dropped base entries: keep as curated, or re-flag any as default?
2. Catalog embed with merge-only user override: confirmed?
3. Hyprland features (layout, runner, shortcuts, menus) are now in scope, not deferred.

## 10. Implemented so far (2026-11-09)

- `config list|diff|apply|restore|history` (section 6 design; lock is a file created with `fileWriteExclusive`, temp files and journal records are created exclusive with their mode).
- Global flag check and the `--json` envelope (sections 1 and 4) for the read-only commands.
- `catalog list|show|groups|check|version`: the catalog is schema 3 (`catalog/README.md`) and is embedded in the binary by `bootstrap/gen-catalog.sh` (CI fails if `src/bxcachy.bxs` is stale). Filters use the `--name=value` form (`--tier=default --group=infra`), because MatchBox `CLIGetArgs` takes `--name value` as a flag plus a positional. `catalog check` is offline: errors exit 1, warnings (unpinned `pkgbuild` refs, default entries without a package) do not. The user override file is deliberately last (extensibility phase).

## 11. Package commands on the catalog (B2, decided 2026-11-09)

Applies to `plan`, `install-plan`, `install`, `optional-*`, `profile-*`, `package-status`, `package-source`. All read the embedded catalog (schema 3). Hardcoded lists in `Main.bx` go away.

### Selection

```
bxcachy install                       # tier default
bxcachy install ID [ID...]            # exactly these apps
bxcachy install --profile=NAME        # a profile
bxcachy install --optional            # default tier plus optional tier
```

- Naming an app is enough. There is **no `--aur` flag**: anything in the catalog installs from its `source` (`pacman`, `aur`, `pkgbuild`, `web`).
- Unknown id: usage error (exit 2), nothing runs.
- Skip reasons: `optional` (not selected), `wrong_shell` and `unresolved` (catalog has no installable source yet; a named `unresolved` app is reported `failed`, exit 3).
- Already installed apps are `skipped` with reason `installed`.
- Section 2 still applies: no `--yes` prints the plan and exits 2; `--dry-run --yes` prints it and exits 0. AUR and `pkgbuild` builds never run as root (exit 4).
- Profiles live in the catalog (0.3.0): a top-level `profiles` list and, per app, a map profile id to `default`/`optional`. `--profile=NAME` installs the profile's `default` members; `--optional` adds its `optional` ones. See `catalog/README.md`.
- Shells: an app may carry `shells` (`hyprland`, `plasma`). The running shell comes from `XDG_CURRENT_DESKTOP`, overridable with `--shell=hyprland|plasma|all`. Non-matching apps are `skipped: wrong_shell`; a named app still installs.

### Per-source steps

| source | step |
|---|---|
| `pacman` | one `pacman -S --needed` call for all pacman apps (sudo shown in the plan) |
| `aur` | AUR helper (yay) as the normal user, apps one at a time |
| `pkgbuild` | PKGBUILD shown, `makepkg` as the normal user, result installed with pacman |
| `web` | a `.desktop` launcher in `~/.local/share/applications/bxcachy-<id>.desktop` running `brave --app=URL` (written atomically, no package). The resolver adds `brave` to the plan when a web app is selected and brave is not installed. |

### Result shape (`--json`, inside the section 4 envelope)

`data` for `plan`, `install-plan` and `install`:

```json
{
  "selection": { "mode": "default|ids|profile|optional", "ids": [], "profile": null },
  "would_install": [ { "id": "git", "source": "pacman", "targets": ["git"] } ],
  "done":    [ { "id": "git", "source": "pacman" } ],
  "failed":  [ { "id": "docker", "source": "pacman", "error": "target not found" } ],
  "skipped": [ { "id": "jq", "reason": "optional" } ]
}
```

- `plan` and `--dry-run` fill `would_install` and leave `done`/`failed` empty. A real run fills `done`/`failed` and leaves `would_install` empty.
- Exit: 0 all done or nothing to do; 5 pacman phase failed, 6 AUR/pkgbuild phase failed (only when nothing succeeded); 7 some done and some failed.
- `package-status ID` exits 0 when installed, 1 when missing; `data` is `{ "id", "source", "installed": true|false }`.
- `package-source ID` prints `{ "id", "source", "targets", "tier", "group" }`.

Human output is the same lists, one app per line with its source.

### Open questions

1. Decided: a `web` app counts as installed when its launcher file exists.

## 12. Implemented so far, B2 (2026-11-09)

- Catalog 0.3.0: `profiles`, per-profile tier, `shells` (section 11, `catalog/README.md`).
- `Resolver` class (selection) and `Packages` class (read-only commands). `plan`, `install-plan`, `optional-plan`, `profile-plan`, `profile-install-plan`, `package-status`, `package-source`, `profile-list`, `desktop-list`, `tui-list`, `web-list`, `optional-list` run on the catalog. Installed state comes from one `pacman -Qq` call (web apps: launcher file).
- `install`, `optional-install`, `profile-install` run on the catalog through `Installer` (one `pacman -S` call, `yay` per AUR app, pinned PKGBUILDs via `git clone` + `makepkg -si`). Rules as in sections 2 and 11: no `--yes` prints the plan (exit 2), `--dry-run` exits 0, root with AUR or PKGBUILD builds exits 4 before any change, a named app without a source exits 3, partial results exit 7 (5 or 6 when nothing succeeded).
- Web apps install as launchers (see section 11 table). The 28 `pkgbuild` apps are pinned to one commit of `omacom/omarchy-pkgs` and install with `git clone`, `git checkout COMMIT`, `makepkg -si` as the normal user (root exits 4). All of them are optional, so a plain `bxcachy install` skips them.
- Not on the catalog: `apps-doctor`, `dev-plan`.

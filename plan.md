# BxCachy — Complete Engineering Plan and Migration Ledger

> Canonical project plan, maintained on `development`. Last updated 2026-11-09.
> **Target changed 2026-11-09 (see section 19): BxCachy builds an opinionated Hyprland + Noctalia desktop on CachyOS, in the spirit of Omarchy. KDE Plasma stays installed side by side and is never removed. Where sections 1 to 18 say "KDE-first" or describe KDE desktop work (M2, M5), section 19 supersedes them.**
> Status labels: **Implemented** means code exists in the repository; **CI-reported passing** means the user reported a passing run; **Verified on CachyOS** requires a recorded real-machine acceptance test; **Planned** means not implemented. Do not confuse these levels.
> The repository's existing docs use “Milestone 1 — native foundation,” while our working conversation has called the same foundational release “Milestone 0.” This plan normalizes it as **M0 — Foundation**, followed by M1+ workstreams. No legacy feature-parity claim is implied.

## 1. Mission and non-negotiable requirements

> **Product focus (owner, 2026-11-09): BxCachy is a kickstarter for developers. The goal is to get a CachyOS machine ready for development quickly, with developer productivity as the mantra: remove setup friction and add tools that make a developer's day easier. Fun (gaming) is supported but optional and never the focus.**

Build **BxCachy**, a reliable, repeatable, CachyOS-first developer-workstation setup and management system inspired by Omarchy's cohesive tooling, without removing or damaging an existing KDE Plasma install (superseded in part by section 19). The end state is a standalone **Linux native executable compiled from BoxLang `.bxs` with MatchBox**, supplemented by Rust/Cargo where Linux integration requires it. Bash is permitted for the initial bootstrap before the native executable exists. Production features must not depend on Python. Favor Arch/CachyOS native tooling and **pacman first, yay for AUR only**.

Core design principles:

1. Never remove or damage an existing KDE Plasma install. `bxcachy setup` installs Hyprland + Noctalia only after an explicit plan and `--yes`, adds a Hyprland session alongside KDE, and never changes the default session without asking (section 19).
2. Explicit opt-in and `--yes` for mutations; support inspect/plan/doctor before apply. Idempotent, reversible configuration changes with backups and meaningful errors.
3. Declarative package catalogs, named profiles, safe package-name validation, official repository preference, AUR only when needed, and never run AUR builds as root.
4. Separate pure planning, system probing, privileged execution, and user configuration. Keep command execution testable with fake tools.
5. No automatic privilege escalation or hidden destructive behavior. Make partial failures visible; pacman + yay are **not one atomic transaction**.
6. Provide a single ordered CI pipeline, globally cancel superseded runs (“last run wins”), with actual MatchBox compilation and native executable tests.
7. Keep a changelog/ledger of implemented versus proposed features and evidence. Do not declare a milestone complete merely because source compiles.
8. During early development, **commit and push directly to `development`; do not create PRs unless requested**.
9. Defer the separate GUI Developer Control Center until core functionality is delivered and stable.

## 2. Source-of-truth inventory and present state

Repository: `ortus-solutions-private/bxcachy`. Active branch: `development`. Current CLI version string: `BxCachy 0.11.0-dev`. Historical Python-based reference release: **v0.10.0**. The inventory document reports **45+ executable entrypoints and 20+ test files** in the legacy archive. The complete Python reference implementation is **not uploaded/ported to this new repository**, so parity cannot be certified until that inventory is recovered and mapped command-by-command.

Current tracked implementation:

| Area | Existing paths | Current behavior / limitation |
| --- | --- | --- |
| Native CLI | `src/bxcachy.bxs` | MatchBox-compiled BoxLang CLI, read-only discovery/plans and selected package commands; not full legacy parity |
| Native commands | `src/bxcachy.bxs` | `version`, `doctor`, `prerequisites`, `desktop-list`, `tui-list`, `web-list`, `optional-list`, `optional-plan`, `profile-list`, `profile-plan`, `profile-install-plan`, `install-plan`, `package-status`, `package-source`, `install`, `optional-install`, `profile-install`, `plan`, `apps-doctor`, `dev-plan`, `help` |
| Package catalogs | `src/bxcachy.bxs`, `scripts/package-manager.sh` | Base: `localsend mpv pacseek`; optional apps and four named profiles. Catalog duplicated in Bash and BoxLang; consolidate |
| Package execution | Native CLI and `scripts/package-manager.sh` | Detect installed, resolve pacman then yay, preflight availability, reject root AUR, report errors; native mutations require `--yes` |
| Bootstrap | `bootstrap/install.sh` | `--check`; `--install --yes` provisions Java 21/git/curl/unzip/rustup; `--install-toolchains --yes` checks Java 21 and non-root, installs MVM if absent, installs/activates MatchBox 0.12.0 |
| Configuration | `scripts/config.sh` | `apply SOURCE DESTINATION --yes`, `restore BACKUP DESTINATION --yes`; same-directory temp + atomic rename, backup, no-op when unchanged, reject symlink destination. This is currently Bash infrastructure, not yet native CLI integration |
| CI | `.github/workflows/ci.yml` | Sequential validate → mocked package tests → Arch prerequisites → MatchBox native compile/smoke/integration → artifact upload |
| Tests | `tests/package-manager-test.sh`, `tests/bootstrap-test.sh`, `tests/config-test.sh`, `tests/native-smoke.sh`, `tests/native-package-integration.sh` | Mock package tools, guardrails, native executable, configuration idempotency/restore; more negative-path coverage needed |
| Documentation | `README.md`, `docs/PORT-STATUS.md`, `docs/NATIVE-MIGRATION-INVENTORY.md` | README warns migration is incomplete; PORT-STATUS contains stale statements and must be reconciled with this plan |

### CI behavior already implemented

- Workflow triggers: pushes to `development`, PRs targeting `development` (legacy trigger retained even though current workflow is direct pushes), manual dispatch.
- `concurrency.group: bxcachy-ci-global`, `cancel-in-progress: true`; only the latest running/pending CI survives.
- Jobs depend on each other, so native compilation cannot bypass prior checks.
- Arch container provisions `jdk21-openjdk`, Git, curl, unzip, rustup; verifies Java/Rust/Cargo.
- Native job installs MVM, installs **MatchBox 0.12.0**, compiles `src/bxcachy.bxs`, runs smoke tests and mocked package integration tests, and uploads `bxcachy-linux-native`.
- Important reproducibility gap: the **MVM installer is fetched from a moving `main` URL**, and the CI uses `archlinux:latest` and `rustup stable`. Pin all production-critical inputs, record checksums, and preserve update procedures.
- User reported the most recent CI passing; no real CachyOS full-bootstrap verification has been recorded here.

## 3. Engineering history — work already completed

The following summarizes actual work and fixes, not a claim that every feature has shipped:

1. Established a new BoxLang/MatchBox native architecture and CLI skeleton, with catalogs for desktop/TUI/web/optional apps and read-only install/profile plans.
2. Added a Bash package adapter with pacman-first, yay fallback, installed-package checks, explicit confirmation, and mocked tests.
3. Added bootstrap safety checks and guarded installation; provisioned Java 21 and Rust prerequisites.
4. Added native `package-status` and `package-source` with package-name validation and explicit nonzero exits.
5. Implemented native `install`, `optional-install`, `profile-install`, including full preflight and root AUR rejection.
6. Consolidated CI into one four-stage dependency chain; configured global `cancel-in-progress` to prevent concurrent runs.
7. Added MatchBox compilation, native smoke tests, artifact publishing and native mock-backed install integration tests.
8. Fixed a shell `pipefail` issue where an intentionally nonzero native validation exit was incorrectly treated as a test failure.
9. Fixed the actual native installer bug: BoxLang `CLIGetArgs()` puts `--yes` into `args.options`, **not** `args.positionals`. Corrected install/profile/optional command parsing.
10. Added tracing and captured installer diagnostics to locate native integration failures.
11. Pinned MatchBox **0.12.0** in CI and the bootstrap's `--install-toolchains` path.
12. Added Bash configuration apply/restore utility with backups, idempotency and symlink-destination checks; added tests and CI wiring.
13. Added root and missing-repository package integration cases; user subsequently reported CI passing.
14. Added an opt-in MVM/MatchBox bootstrap command and confirmation test.
15. Switched collaboration policy from PRs to **direct commits on `development`** after the earlier foundation PR was merged.

Selected development history (use Git history for authoritative chronology): `d2d0eaa` smoke fix; `2401445` native installer; `243250e` native integration CI; `f1b109e` MatchBox pin; `2626b41` diagnostic smoke; `4b13a53` integration tracing; `b61b5f1` output capture; `1f2f075`/`665e85a` CLI option fix; `55005c9` config utility; `1f29806` config tests; `fc8e6b2` CI config tests; `aa86bf5` toolchain bootstrap; `b0e7f0c` bootstrap confirmation test. This list is illustrative, not a complete `git log`.

## 4. Milestone M0 — Foundation and reproducible native bootstrap

**Goal:** from a clean supported CachyOS/KDE machine, safely provision prerequisites, compile or install a reproducible native CLI, exercise its package/configuration operations, and recover from expected failures.

### M0-A — Native command contract (implemented; hardening pending)

- [x] BoxLang source compiles with MatchBox and exposes a Linux executable.
- [x] Read-only discovery/planning commands.
- [x] Catalog-driven native install, optional-install and profile-install, requiring confirmation.
- [x] Installed/official/AUR lookup, full preflight, root guard, exit-code reporting.
- [x] CLIGetArgs named-option parsing corrected.
- [ ] Centralize package/profile catalogs in one versioned source rather than duplicate Bash/BoxLang constants.
- [ ] Validate unknown flags, duplicate options, empty arguments, unsupported environments, missing executables, timeout and subprocess exceptions.
- [ ] Define stable exit-code map and machine-readable `--json` output.
- [ ] Provide `--dry-run` for every mutating command and explicit display of the exact plan before apply.
- [ ] Ensure all subprocess invocations avoid shell injection, preserve argument boundaries and work when PATH entries are absent.
- [ ] Add native tests for pacman failure, yay failure after pacman success, command timeout, already-installed no-op, duplicate packages, missing sudo, and user cancellation.
- [ ] Record successful and failed packages separately; document manual recovery. Do not claim transactional rollback.

### M0-B — Bootstrap/toolchain (partially implemented; **critical path**)

- [x] Arch/CachyOS pacman detection and package presence check.
- [x] Guard `--install --yes` and `--install-toolchains --yes`.
- [x] Install Java 21/git/curl/unzip/rustup packages.
- [x] Verify Java 21 and require non-root for MVM/MatchBox provisioning.
- [x] Install/activate MatchBox 0.12.0 via MVM.
- [ ] Select, verify and pin an exact **BVM installer** release/tag/commit and SHA-256; install BVM in the normal user's home.
- [ ] Select and pin the desired **BoxLang runtime** release via BVM; verify `boxlang --version` and Java compatibility.
- [ ] Pin the **MVM installer** to an immutable tag/commit and checksum; do not fetch mutable `main` in production.
- [ ] Decide whether MatchBox 0.12.0 remains the supported compiler version after compatibility tests; capture artifact checksums.
- [ ] Pin CI action SHAs, Arch base image digest and Rust toolchain where feasible.
- [ ] Add `--check` output for Java, BVM, BoxLang, MVM, MatchBox, Rust/Cargo, architecture, disk space, OS and PATH.
- [ ] Build a complete `bootstrap/install.sh --install --yes` path that sequences packages → user toolchains → native executable installation. Avoid calling user-level installers under sudo.
- [ ] Make bootstrap idempotent and rerunnable after interrupted downloads, network errors and partial setup.
- [ ] Verify downloaded scripts and binaries against pinned digests **before** executing; no blind curl-to-shell.
- [ ] Support a documented offline/manual install path using a verified CI release artifact.
- [ ] Add mock-based bootstrap tests for missing Java, root execution, missing network, checksum mismatch, version mismatch, rerun, partial recovery and no-confirmation.
- [ ] Execute a real clean CachyOS KDE VM/hardware bootstrap and record OS build, commands, versions, results and logs.

### M0-C — Configuration and safety (partially implemented)

- [x] Bash config apply and restore, backup, atomic replacement, idempotent no-op, symlink-destination rejection.
- [x] Tests for apply/restore/idempotency/confirmation and basic unsafe paths.
- [ ] Expose configuration operations through the native BoxLang CLI (Bash may remain bootstrap-only).
- [ ] Support per-feature config manifests and a transaction journal/backup index; provide `config list`, `config diff`, `config apply`, `config restore`.
- [ ] Harden against symlinked ancestor paths, TOCTOU races, special files, owner/mode mistakes, interrupted writes, conflicting concurrent invocations and disk-full failures.
- [ ] Validate that atomic replacement is on the same filesystem and preserve intended permissions/ownership.
- [ ] Define a safe policy for user edits and drift detection; never overwrite untracked customization without confirmation.
- [ ] Make restore selection unambiguous and document retention/cleanup.
- [ ] Add integration tests for concurrency, rollback of multi-file configurations and recovery from mid-apply failure.

### M0-D — CI, release engineering and acceptance

- [x] Single ordered CI with global supersession cancellation.
- [x] Shell syntax checks, mocked package/bootstrap/config tests, Arch prerequisites, native compile, smoke/integration tests, artifact upload.
- [x] MatchBox 0.12.0 version assertion.
- [x] User reported a passing pipeline after installer argument fixes.
- [ ] Add BVM/BoxLang/MVM pinned installer validation and full bootstrap tests to CI.
- [ ] Add a native `--help`/command-contract snapshot test, version consistency test and release artifact execution check.
- [ ] Run at least one **real CachyOS KDE** install-and-recovery test; mock Ubuntu tests and an Arch container alone are insufficient.
- [ ] Verify no Python dependency in the produced binary or its production workflow.
- [ ] Produce checksummed, versioned native artifacts and install/uninstall instructions.
- [ ] Review CI global cancellation impact on release publishing; prevent an unrelated new push from leaving partially published releases.
- [ ] Record test matrix, environment and exact passing run URL in a milestone sign-off entry.
- [ ] Update `README.md` and `docs/PORT-STATUS.md` after acceptance; they currently describe incomplete/stale status.

**M0 definition of done:** all M0 critical-path items above complete, all CI jobs green on the final `development` commit, verified clean CachyOS KDE install, idempotent rerun, native executable functional, verified backups/restore, no silent desktop changes, and documented recovery. **Current M0 status: IN PROGRESS** (passing CI was reported, but bootstrap and clean-machine gates remain).

## 5. Milestone M1 — Developer applications, profiles and package management

**Goal:** fully usable developer-machine profiles, not merely print-only plans.

- Single declarative application catalog: canonical ID, display name, category, package names per source, required/optional status, license/notes, dependencies, post-install check, upgrade/remove commands, GUI/TUI/web links.
- Named profiles: `core`, `jvm`, `containers`, `terminal`; extend with `web`, `backend`, `ai`, `ops`, `desktop` and `full` only after confirming package inventories.
- Java JDK 21+ selection, Maven, Gradle, BoxLang/BVM/MVM/MatchBox, Git/GitHub CLI, Node.js/npm/pnpm, editors, Ghostty, Zsh/Fish, eza, bat, fastfetch, fzf, ripgrep, fd, jq, yq, lazygit, btop, neovim, yazi and optional tools.
- pacman-first, yay fallback; install/update/doctor/remove with explicit preview and confirmation, dependency checks, protected package exclusions and clean logs.
- Dotfile setup for aliases `ll`/`la` → eza, `cat` → bat, terminal theme and fastfetch; respect existing Zsh configuration and shell selection.
- Profile export/import and reproducible lockfiles, environment detection, dependency resolution, `--dry-run`, `--json`, error summaries.
- Tests: profile expansion, source selection, idempotency, missing packages, user permissions, unsupported distro, no accidental package removal.
- **Acceptance:** clean CachyOS machine can apply and verify a profile, rerun without unnecessary changes, and restore modified configuration.

## 6. Milestone M2 — KDE Plasma desktop and Omarchy-style experience

**Goal:** cohesive keyboard-first workflow **inside KDE**, retaining native KDE behavior.

- KDE session detection and strict non-destructive safeguards.
- Discoverable launcher/menu for BxCachy tasks (TUI initially); categorized developer, apps, system, cloud and AI actions.
- KWin shortcuts: Super launcher behavior, window tiling/switching, workspace navigation, hide/show panel, terminal launcher, application shortcuts; preserve existing assignments and allow reset.
- KDE panel/dock, widgets, themes, icon packs, wallpapers, window decorations, title bars, accent and dark/light settings, with per-change preview and backups.
- Optional Omarchy-inspired application menus and tooling, without installing or forcing Hyprland, Niri or Caelestia.
- Ghostty/Konsole integrations, file-manager actions, notifications, clipboard and screenshot utilities.
- KDE version/Wayland/X11 detection, conflict detection, rollback and manual restore instructions.
- Test in KDE Plasma on a real or VM desktop; verify minimize/maximize/close, panels, multi-monitor, suspend/resume and accessibility are unaffected.
- **Acceptance:** all desktop actions are opt-in, reversible, tested on KDE, and never silently replace the session.

## 7. Milestone M3 — Containers, local AI, databases, networking and virtualization

- Podman-first workflow with optional Docker CLI compatibility and explicit engine choice; diagnose storage driver, btrfs overlay/fuse-overlayfs, rootless permissions, sockets, volumes and registries.
- Container templates for development services and reproducible start/stop/status/logs; avoid conflicting with existing Docker/Podman setups.
- Local inference: Ollama/LM Studio-compatible endpoints, model discovery/pull/status, quantization/resource checks, CPU/GPU capabilities, tool-calling and embedding endpoints.
- Database service catalog: PostgreSQL, Redis, Couchbase, vector stores (e.g. pgvector/Chroma/Milvus), lifecycle and safe persistent volumes.
- JVM and BoxLang runtime introspection, JDK compatibility, developer environment health.
- Networking: DNS, reverse proxies, TLS, local domains, Tailscale/VPN compatibility, firewall ports, route and service diagnostics; never overwrite network settings without backup.
- VM support: KVM/QEMU/libvirt where supported; CPU virtualization checks, disk safety and opt-in networking.
- Resource checks: memory, GPU/VRAM, disk capacity, model sizes and local inference constraints.
- Tests for privileged/rootless behavior, container storage, service start/stop, recovery and preservation of existing services.
- **Acceptance:** profiles install only requested services, persistent data survives restarts, and failures do not corrupt host networking or existing containers.

## 8. Milestone M4 — Cloud center, storage and developer services

- Provider-neutral cloud-center CLI with clear boundaries between local config and external account operations.
- rclone/FUSE setup, mount/unmount/status, permissions, credential isolation and encrypted secret handling.
- Optional provider profiles (cloud object storage, sync and backup) based on verified provider APIs and user authorization.
- Mount persistence, reconnect/retry, offline handling, safe unmount and failure recovery.
- Cloud CLI tool installation, credential doctor, profile selection and audit-friendly logs.
- No credentials in repositories, process arguments, debug logs or exported profiles; secrets via OS keyring or another approved secret store.
- Tests for missing credentials, expired tokens, disconnected network, remount and data-loss prevention.
- **Acceptance:** mount/sync operations are explicit, credentials protected, and disconnection/recovery tested.

## 9. Milestone M5 — Desktop productivity integrations

- Dolphin Quick Look preview: file-type support, keyboard activation, KDE compatibility, packaging and uninstall.
- Dictation: microphone permissions, local versus remote STT options, model download, push-to-talk shortcut, insertion into focused application and privacy defaults.
- Notification center, check-in/health prompts, clipboard/file actions, screenshots and other system integrations as supported by the v0.10.0 inventory.
- Optional accessibility, audio-device and keyboard-layout helpers (including Spanish characters).
- Handle Wayland security constraints correctly; never promise global keyboard injection without a verified supported mechanism.
- Tests on KDE Wayland/X11, multi-user setups, permissions and fallback behavior.
- **Acceptance:** feature-level enable/disable, no regressions to standard KDE input/audio/file workflows.

## 10. Milestone M6 — Legacy parity, stabilization and release

- Recover the v0.10.0 source archive; enumerate every one of the 45+ entrypoints and 20+ tests, plus configs/assets.
- Maintain a migration matrix: legacy command → native command/replacement → owner → implementation → tests → acceptance evidence.
- For each legacy feature, either implement full behavior or document an approved replacement; read-only placeholders do not count as parity.
- Remove Python from the production execution path; keep legacy implementation available for comparison until migration acceptance.
- Integrate native unit tests (including TestBox where appropriate), mocked process tests, real Arch/CachyOS integration, KDE desktop tests, security tests and performance checks.
- Provide upgrade/downgrade/migration, backups, uninstall, support matrix, troubleshooting, release notes and checksum verification.
- Test fresh install, upgrade from v0.10.0, reinstall, partial failure, restore, unsupported hardware and rollback.
- Tag a versioned release only after parity and acceptance gates pass; never silently replace the previous functional release.

## 11. Deferred: BxCachy Developer Control Center GUI

**Explicitly deferred until core CLI and major workstreams are complete.** The planned GUI is a separate `bxcachy-desktop` application with **Quasar + Vue 3 (JavaScript)**, **Tauri 2 + Rust native shell**, and a secure command bridge reusing the native BxCachy services/CLI (not a second business-logic implementation). UX: polished macOS/Raycast-like dark/light interface, responsive navigation, status/health, catalog/profile installer, preview/apply/rollback, notifications, logs, cloud/AI/dev tooling panels and search/command palette. Preserve KDE controls and avoid embedding privileged shell execution in the renderer. Build signed/distributable Linux packages, accessibility and E2E tests after CLI APIs stabilize.

## 12. Proposed code organization

```text
plan.md                           # This canonical plan and decision log
README.md                         # Supported install and current status
src/bxcachy.bxs                   # Current native entrypoint
src/commands/                     # Proposed command handlers
src/services/                     # Proposed package/config/doctor services
src/catalog/                      # Proposed canonical package/profile data
src/platform/                     # Proposed CachyOS/KDE/Arch adapters
bootstrap/install.sh              # Minimal trusted first-run bootstrap
scripts/package-manager.sh        # Existing transitional adapter
scripts/config.sh                 # Existing transitional config helper
tests/                            # Unit, mocks, native, Arch, KDE acceptance
docs/NATIVE-MIGRATION-INVENTORY.md
docs/PORT-STATUS.md
docs/architecture/                # Proposed ADRs and threat model
.github/workflows/ci.yml          # One ordered, globally superseding pipeline
```

This is a **target structure**; only paths identified as existing above should be assumed to exist.

## 13. Testing and release matrix

| Layer | What to prove | Current / planned |
| --- | --- | --- |
| Static | Bash syntax, CLI contract, catalog schema, YAML and lint | Bash/CLI checks implemented; schema/lint planned |
| Mock package | pacman/yay precedence, root guard, unavailable preflight, no partial mutation on preflight failure | Implemented for primary cases; failure matrix planned |
| Bootstrap | confirmation, prerequisites, pinned verified downloads, idempotency | Confirmation implemented; full provisioning and checksum tests planned |
| Config | no-op, backup, atomic apply, restore, unsafe path rejection | Core implemented; race/disk-full/multi-file planned |
| Native | MatchBox compilation, version, help, invalid inputs, installation paths | Implemented; expanded error matrix planned |
| Arch | Java/Rust provisioning and package tooling | Arch container implemented; real install planned |
| CachyOS KDE | fresh setup, desktop preservation, rerun, rollback | Not yet evidenced |
| Release | executable checksum, provenance, install/upgrade/uninstall, smoke after artifact download | Artifact upload implemented; remaining planned |
| Security | argument injection, symlink races, secrets, privilege boundaries, supply chain | Partial guards; audit planned |

Every bug fix should add a regression test; every mutating command should test success, no-op, invalid input, dependency failure, privilege rejection, and recovery. CI must execute tests rather than only parse scripts. Report exact failing command and exit code, avoiding pipelines that obscure failures.

## 14. Immediate ordered execution backlog

**Next work is M0, not M1.** Execute in small direct commits to `development` and verify CI after each coherent change.

1. **Toolchain supply chain:** identify supported BVM/BoxLang/MVM release URLs, pin exact versions and immutable installer digests, add verification script and test fixtures.
2. **Complete bootstrap:** implement BVM + BoxLang install, verify versions, sequence Java/Rust/MVM/MatchBox, install native executable, make repeated runs safe.
3. **Bootstrap tests:** mock every external tool and failure mode, including checksum mismatch and root/user split; ensure no network in unit tests.
4. **Native config integration:** expose apply/diff/restore through BoxLang CLI and test safely with temporary directories.
5. **Failure hardening:** address pacman/yay partial success, missing binaries, timeouts, options, PATH and error messages; retain clear recovery instructions.
6. **Reproducible CI:** immutable action/toolchain pins, clean native build, verify artifact after upload/download, capture checksums and exact tool versions.
7. **CachyOS acceptance:** run a clean KDE VM/hardware install, inspect changes, rerun, restore, verify normal KDE behavior, document evidence.
8. **M0 sign-off:** update README/PORT-STATUS and version/release notes only after every gate passes.
9. **Then M1:** catalog consolidation, complete developer tooling profiles and package lifecycle; continue through M2–M6 in order, adjusting priorities based on recovered legacy inventory.

## 15. Risks, dependencies and explicit decisions

- **Missing legacy archive:** cannot guarantee parity or accurately count migrated features without the original v0.10.0 source. Recover it before M6 sign-off.
- **Moving installer references:** current MVM bootstrap/CI fetches mutable `main`; supply-chain risk until pinned and checksum-verified.
- **Partial package transactions:** a successful pacman phase followed by a failed yay phase leaves some packages installed; document reconciliation, do not claim rollback.
- **Privilege and filesystem safety:** `sudo`, AUR, config ownership, symlink traversal and network modifications require threat-model review.
- **KDE preservation:** all theme/shortcut/panel changes must be previewed, backed up and reversible.
- **Hardware variation:** GPU, Btrfs, Wayland, multi-monitor and rootless Podman vary by workstation; support matrix and hardware testing needed.
- **CI evidence:** user-reported passing CI is useful but does not replace an independently recorded passing run URL and real CachyOS test.
- **No PRs for now:** direct development commits only; retain code review and release protection before production.
- **GUI deferred:** do not divert core migration time to Tauri/Quasar until core CLI feature parity is stable.
- **Version naming:** current executable says 0.11.0-dev; M0/M1 milestone names are planning labels, not semantic versions.

## 16. Maintenance protocol

Update this file in the same commit as any material scope/architecture/acceptance change. Update checkboxes only when supported by code and tests. Attach a passing run URL, commit SHA, tested environment and any caveats to milestone sign-off. Keep `docs/PORT-STATUS.md` synchronized and avoid optimistic “complete” claims. When new legacy files are recovered, expand the parity matrix rather than silently dropping features.

**Current bottom line:** native CLI, safe package planning/install, configuration backup/restore, ordered CI, native compilation, and MatchBox bootstrap are implemented; the user reports CI passing. **Full BVM/BoxLang pinned bootstrap, real CachyOS validation, native configuration integration and complete legacy feature parity are still pending.**


## 17. Audited historical v0.10.0 source archive — recovered 2026-11-08

**New evidence:** The actual original file `BxCachy-v0.10.0-integration-hardening.zip` was recovered from prior conversation artifacts and inspected, rather than inferred from README statements. The ZIP has **115 archive entries (including directories)**, including **44 executable files under `BxCachy/bin/`** and **20 Python test files** (including two legacy tests). Its SHA-256 is `94e1722eb7d5e915a357a98f02fbbf3f7d2ae5dce01cdbdd1b20b1072a4e5819`. This is the precise historical reference to preserve. The current native CLI is **not** equivalent to those 44 entrypoints.

### Complete original executable inventory and migration tracking

Status **P** = planned/not demonstrated as equivalent in the new native CLI; **S** = partial native scaffold exists, but legacy behavior is not yet feature-parity audited. A native command with a similar name is not proof of behavioral equivalence.

| Original executable | Native parity | Migration workstream |
| --- | --- | --- |
| `bxcachy` | S | M0/M6 root dispatcher |
| `bxcachy-apps` | S | M1 app catalog and installation |
| `bxcachy-app-manager` | S | M1 install/update/remove/selection |
| `bxcachy-catalog` | S | M1 catalog browsing/import |
| `bxcachy-profile` | S | M1 profile resolution |
| `bxcachy-base` | P | M1 base workstation setup |
| `bxcachy-extras` | P | M1 optional tools |
| `bxcachy-dev` | S | M1 Java/BoxLang/developer tooling |
| `bxcachy-podman` | P | M3 rootless containers |
| `bxcachy-ai` | P | M3 local inference |
| `bxcachy-vector` | P | M3 vector stores |
| `bxcachy-db` | P | M3 databases |
| `bxcachy-db-center` | P | M3 database service management |
| `bxcachy-vm` | P | M3 virtualization |
| `bxcachy-network` | P | M3 network tooling |
| `bxcachy-cloud` | P | M4 cloud setup |
| `bxcachy-cloud-center` | P | M4 cloud center |
| `bxcachy-cloud-services` | P | M4 rclone/systemd |
| `bxcachy-files` | P | M4 file integration |
| `bxcachy-quicklook` | P | M5 Dolphin preview |
| `bxcachy-dictation` | P | M5 speech input |
| `bxcachy-integrations` | P | M5 integration orchestration |
| `bxcachy-desktop` | P | M2 KDE/optional Hyprland desktop |
| `bxcachy-desktop-keys` | P | M2 desktop key bindings |
| `bxcachy-mac-keys` | P | M2 macOS-like keyboard mapping |
| `bxcachy-omarchy-base` | P | M2 Omarchy-inspired defaults |
| `bxcachy-layout` | P | M2 tiling/floating |
| `bxcachy-themes` | P | M2 theme management |
| `bxcachy-icons` | P | M2 icon assets |
| `bxcachy-runner` | P | M2 launcher provider selection |
| `bxcachy-menu` | P | M2 task menu |
| `omarchy-menu` | P | M2 terminal menu |
| `omarchy-gui` | P | M2 graphical menu |
| `shortcuts` | P | M2 shortcuts |
| `theme-manager` | P | M2 theme utility |
| `bxcachy-web` | P | M1 web app links |
| `bxcachy-system` | P | M2/M3 system health |
| `bxcachy-config` | S | M0 native configuration integration |
| `bxcachy-first-run` | P | M0 onboarding |
| `install` | S | M0 installer parity |
| `provision` | S | M0 provisioning |
| `desktop-install` | P | M2 graphical dependencies |
| `menu-install` | P | M2 menu installation |
| `setup-tui` | P | M2 terminal setup |

### Original automated tests (20 files)

`test_dev.py`, `test_extras.py`, `legacy/test_provision.py`, `legacy/test_v05.py`, `test_integrations_099.py`, `test_app_manager.py`, `test_catalog_v087.py`, `test_bxcachy.py`, `test_phases.py`, `test_v085.py`, `test_integrations_100.py`, `test_v08.py`, `test_layout.py`, `test_ai_extended.py`, `test_icons.py`, `test_ai.py`, `test_base.py`, `test_vector.py`, `test_omarchy_base.py`, `test_runner_backends.py`.

Each test suite should be mapped to equivalent native unit/integration assertions; retain the historical Python suite only as archival regression evidence, not as a production dependency.

### Previously omitted implementation and design details recovered

1. **Launcher portability:** `runner show|set|doctor`, provider options `system`, `noctalia`, `rofi`, `walker`, `krunner`, `custom`. `system` must not override the existing launcher; custom commands use JSON argv arrays, not shell expansion. Preserve Hyprland `Super+Space`.
2. **Shortcut isolation:** `~/.config/bxcachy/shortcuts.json` and generated `~/.config/hypr/bxcachy-keys.conf`. Default BxCachy shortcut `Super+Alt+Space` is **generated but not activated**. Do not modify KDE shortcuts. Hyprland Lua-managed configurations need explicit handling.
3. **Window management:** original `layout window toggle|float|tile` and `layout workspace toggle|float|tile`; original bindings `Super+V` and `Super+Alt+V`. Requires active Hyprland/hyprctl; **not** a KDE window-button replacement.
4. **Menu:** Rofi-wayland graphical menu, terminal menu and user overrides in `~/.config/bxcachy/menu.json`; menu actions are argv arrays. Phosphor icon identifiers and cached official SVGs were used.
5. **Podman:** original package manifest included conmon, crun, containers-common, passt, slirp4netns, fuse-overlayfs, netavark, aardvark-dns, Buildah, Skopeo, podman-compose and shadow; optional rootless socket and compose doctor. Never overwrite Btrfs storage config or replace Docker automatically.
6. **Developer setup:** original installer offered SDKMAN!, Java 21 selection, Maven, Gradle, BoxLang Quick Installer, BVM and MVM. External scripts were downloaded to temporary files and required an additional typed `EXECUTE` confirmation. Distinguish single-version BoxLang quick installer from BVM runtime management.
7. **Dolphin Quick Look:** v0.10.0 explicitly supports a **Dolphin context-menu action**, not an unsupported global Spacebar interception. Qt/PySide6 dependencies and service-menu installation were part of the original workflow.
8. **Dictation:** original Hyprland shortcut template is generated automatically but **activation remains opt-in** because `Alt+Space` may conflict. Superwhisper/Voxtype command compatibility must be checked on the target workstation.
9. **Cloud services:** idempotent per-user systemd units; never overwrite user-modified units. `cloud-services install REMOTE --yes` requires an already authenticated rclone remote. An rclone mount **is not offline synchronization**.
10. **App selection UI:** historical interactive catalog picker had **397 entries** and **29 original defaults** at one review point; later v0.9.x picker versions revised catalog/selection. The authoritative final default set must be extracted from the archived `catalog/apps.json` and `catalog/app-profile.json`, not reconstructed from screenshots or older HTML.
11. **Historical assets:** archive contains `catalog/apps.json`, `catalog/app-profile.json`, `catalog/installers.json`, `catalog/app-picker.html`, `config/bxcachy.json`, `config/shortcuts.json`, `config/omarchy-keys.conf`, `config/omarchy-keys.lua`, `menu/default.json` and `menu/custom.example.json`, plus version-specific READMEs and icons.
12. **No premature GUI:** the Quasar/Vue + Tauri unified Control Center was already explicitly deferred in v0.10.0. A Rofi menu is an existing legacy integration, not the deferred Control Center.

### Archive preservation and validation procedure

Canonical historical filename: `BxCachy-v0.10.0-integration-hardening.zip`. Expected SHA-256: `94e1722eb7d5e915a357a98f02fbbf3f7d2ae5dce01cdbdd1b20b1072a4e5819`. Expected: 115 archive entries (including directories); verify 44 bin entrypoints and 20 tests against the manifest. Preserve the original ZIP **without modifying its bytes**, ideally under `artifacts/legacy/` or as a versioned GitHub release asset. Add an archival README containing this checksum and the rule that legacy Python must not become a native runtime dependency. **Archival repository upload is not yet verified; do not claim it is committed until the exact ZIP is present in GitHub.**

### Audit limitations

This audit combines the actual recovered v0.10.0 archive inventory and its documented behavior with accessible BxCachy discussion history and the current repository. It is more complete than the initial plan, but it is **not yet a function-by-function diff of all 104 archived files**. Each row marked S/P needs a command-level behavioral test and a final owner/acceptance record. The historical ZIP must be preserved in the repository before deleting or replacing any external copy.

## 18. Progress log

- 2026-11-09: A1 legacy source tree committed (104 files, reference only). A2 to A4 real Arch container harness (`tests/arch/`) and CI stage 5; run 42539644723 green, 23/23 steps. Not yet verified on real CachyOS KDE. A5 draft command contract: [docs/architecture/COMMAND-CONTRACT.md](docs/architecture/COMMAND-CONTRACT.md), pending review.
- 2026-11-09 decisions: legacy tree is the real source, kept untouched, never backed up or copied. Product config backup/restore/journal design stays (an earlier edit removing it was a misreading and is reverted). yay is installed by bootstrap only if absent. Exit codes 7 to 9 accepted. Catalog check design and first measurement in the command contract, section 8.

## 19. Target: opinionated Hyprland + Noctalia on CachyOS (supersedes KDE-first)

Decided 2026-11-09. BxCachy turns a vanilla CachyOS install into a finished, curated Hyprland + Noctalia desktop with our opinions, similar in spirit to Omarchy 4.5, with a smooth transition from macOS as the guiding goal. If Hyprland or Noctalia is missing, `bxcachy setup` installs and configures it. KDE stays installed side by side as a fallback session. Legacy v0.10.0 is a feature reference, not code to port.

### 19.1 Research summary (Omarchy 4.5, public sources, 2026-11-09)

Omarchy 4.5 (RC1 at the time of the sources; DistroWatch reports a final 4.5.0) is a full distro: own ISO and installer, own Arch mirror, own in-house shell, releases delivered as pacman packages with migrations, four update channels (stable, rc, edge, dev), a snapshot before each update, direct `pacman -Syu` blocked, `omarchy reinstall` to reset configs. Experience features worth matching: one menu (`Super+Alt+Space`) and a CLI that mirrors it; key cheat sheet (`Super+K`); per-workspace layout cycling tiling/scrolling/floating (`Super+L`) with themed titlebars, a dock and minimize; per-monitor workspaces; an Appearance menu (theme, background, font, bar, dock, gaps, corners, opacity, animations); about 19 themes applied across terminal, Neovim, btop and lock screen, with theme intros, video wallpapers and a remembered wallpaper per theme; rebuilt notifications (grouping, snooze, Do Not Disturb, history); screenshots, OCR, QR and screen recording; unified clipboard with history; dictation (Superwhisper or Voxtype, hold-to-talk); a drop-down agent console (`Super+~`), 23 tracked AI agents, multiple accounts and usage meters; mise language environments, Docker, LazyVim, tmux layouts, shell tools; web apps as frameless windows; Install menu for gaming, a Windows VM and Microsoft 365 web apps; fingerprint and FIDO2 unlock; 50 languages and input methods.

We do not copy: own ISO/installer, own mirror, ARM and Apple Silicon, own shell (Noctalia provides it), the Quasar/Tauri GUI (still deferred).

Noctalia: Quickshell-based shell with multi-monitor bars, dock, launcher, control center, notifications, wallpaper picker, OSD, lock screen, session panel, clipboard, desktop widgets; TOML config with hot reload, theme/palette system, plugins, IPC. Verified in the CachyOS-enabled test container: `noctalia` 5.4.1 is in Arch `extra`; `noctalia-shell` and `noctalia-qs` are in the `cachyos` repo; `quickshell`, `hyprland`, `hyprlock`, `hypridle`, `hyprpaper`, `uwsm`, `ghostty` are in `extra`; `yay`, `paru`, `brave-bin` are in the `cachyos` repo; and CachyOS ships the meta-package `cachyos-hypr-noctalia` 1.2.6 (depends on `hyprland noctalia uwsm kitty dolphin grim slurp wl-clipboard hyprpicker nwg-look qt6ct adw-gtk-theme brightnessctl ddcutil` and fonts; conflicts with `cachyos-desktop-settings`). Still to verify: whether `noctalia` and `noctalia-shell` are the same product (the CachyOS package page lists `noctalia-shell` 5.4.1 depending on `noctalia-qs`), and how Hyprland keybinds should call Noctalia IPC.

### 19.2 Supported feature set

1. `bxcachy setup`: detect CachyOS, Hyprland, Noctalia; install and configure what is missing (plan first, `--yes` to apply). Prefer the CachyOS meta-package where it fits.
2. Curated app catalog with categories, a default tier and optional installs; macOS-transition equivalents.
3. Web apps as frameless windows.
4. Themes and wallpapers across terminal, Neovim, btop, GTK/Qt and Noctalia colors.
5. Menu, key cheat sheet and our own keybinding set in a BxCachy-owned Hyprland file; macOS-style key option.
6. Layouts: tiling, scrolling, floating cycle.
7. Launcher/runner provider choice that never overrides the existing launcher.
8. Capture: screenshot, OCR, QR, screen recording.
9. Clipboard history.
10. Dictation, opt-in.
11. AI agents, drop-down console, local models.
12. Developer tools: Java 21, Maven, Gradle, BoxLang, BVM, MVM, mise, shell tools.
13. Containers, databases, vector stores, VMs, networking.
14. Cloud storage (rclone mounts as per-user services).
15. `bxcachy update` with migrations, `doctor`, `reinstall`.
16. Hardware auth, languages and input methods (later).

### 19.3 Build order

1. CachyOS repos in the test container (done 2026-11-09, `tests/arch/cachyos-repos.sh`).
2. Simple catalog checker (validate the file, resolve against CachyOS repos and AUR) with CI; finish curating the catalog by category.
3. Pinned toolchain and full bootstrap; yay only if absent.
4. Native core: shared argument parser, exit codes, `--json`, `--dry-run`, embedded catalog with merge-only user override.
5. Native config service in BoxLang (prove file operations in the harness first; Bash only for bootstrap).
6. `bxcachy setup` for Hyprland + Noctalia.
7. Keybindings, menu, layouts, themes (the identity layer).
8. Capture, clipboard, dictation, AI console.
9. Dev tools, containers, databases, VMs, networking, cloud.
10. Update engine with migrations.
11. Real CachyOS hardware acceptance (needs a real machine or VM).

### 19.4 Decisions

KDE kept side by side. Catalog: legacy `apps.json` is canonical; `filezilla` and `podman-tui` join the default tier (63 defaults); `dbeaver`, `krdc`, `rustdesk` remain optional installs; full category review pending. Catalog is embedded with a merge-only user override. Config backup/restore design stays. Legacy source tree is kept untouched.
- 2026-11-09 script installs: catalog gets a `script` source (url, optional args, `check` command) for tools installed by upstream scripts (BoxLang, BVM, MVM, pi). Decision: no checksum pinning; the script is downloaded to a temp file, shown, run as the normal user (never root) only after the typed `EXECUTE` confirmation. This supersedes the M0-B items that require pinned SHA-256 for BVM/MVM installers; the risk (a changed or tampered upstream script is not detected) is accepted by the owner. Version pins that already exist (MatchBox 0.12.0) stay.
- 2026-11-09 open: the 7 default catalog entries with no repo package (`intellij zap-whatsapp grokbot pi-agent herder tmog notion-desktop`). Candidates found: AUR `zapzap`, `grok-bot-desktop`, `pi-coding-agent-bin`, `tmog-bin`, `notion-app-electron`; Flathub `com.jetbrains.IntelliJ-IDEA-Community`; nothing found for `herder`. Waiting for the owner's installed package names.
- 2026-11-09 containers: Podman is the default container engine (Podman, Buildah, Skopeo, podman-compose, podman-desktop, podman-tui) instead of Docker. Docker + Compose stay in the catalog as an optional install. `podman-docker` is not installed by default because it conflicts with the `docker` package. `podman-tui` is an AUR package, not an official repo package.
- 2026-11-09 Omarchy 4.5 apps: all Omarchy 4.5 desktop apps are in the catalog as at least optional (final default/required set decided later). Zen and Helium are optional browsers. Source investigation: `monologue omacut omasnap omacalc gliff superwhisper-bin` (and `hype signed omawrite cliamp disktree-bin`) have public PKGBUILDs in `omacom/omarchy-pkgs` (`pkgbuilds/<name>/PKGBUILD`, MIT; `superwhisper-bin` repackages a proprietary vendor binary). Upstream sources are GitHub tag tarballs. All 65 dependency names across these PKGBUILDs resolve in the CachyOS/Arch repos, so none needs an Omarchy-only package. `elsewhen` is now a plugin of the Omarchy shell with no standalone package. Real builds are NOT yet tested (the authoring sandbox blocks GitHub downloads); a CI job that builds them in the Arch container is the next step. New catalog source type: `pkgbuild` (repo, path, pinned ref), built with `makepkg` as the normal user.
- 2026-11-09 gaming: optional only. Catalog offers the CachyOS gaming bundle (`cachyos-gaming-meta`, `cachyos-gaming-applications`: Steam, Lutris, Heroic, Faugus, gamescope, MangoHud, GOverlay, Proton/Wine), Steam, Lutris, Heroic, RetroArch, Prism Launcher, Minecraft Launcher (AUR), ProtonUp-Qt, Sunshine, Discord, plus cloud gaming: Xbox Cloud Gaming (web), Greenlight (unofficial Xbox Remote Play client, AUR) and GeForce NOW (unofficial Electron wrapper, AUR; NVIDIA has no official Linux app). Moonlight stays default (Omarchy ships it).
- 2026-11-09 base catalog (owner decision): the base is the owner's own picks (default) plus ALL desktop and web apps that Omarchy ships or lists (optional). The Omarchy app inventory comes from the community store omarchyapps.com (207 packages in Omarchy's repository) plus the Omarchy 4.5 release notes and manual hotkey table; the store is unofficial. Result: 64 default, 136 optional, 351 not selected, of 551 rows. Install sources for the 89 Omarchy desktop apps: 25 in CachyOS/Arch repos, 30 in the AUR, 32 buildable only from Omarchy PKGBUILDs (`omacom/omarchy-pkgs`), 2 not installable (`elsewhen` is an Omarchy shell plugin; `lmstudio` has no public PKGBUILD). The owner's previously unresolved defaults `tmog`, `grokbot`, `notion-desktop` and `herdr` are Omarchy repository packages (`tmog-bin`, `grok-bot`, `notion-desktop`, `herdr`) and now resolve; `intellij`, `zap-whatsapp` and `pi-agent` still do not. Curation and fine-tuning happen after the owner starts testing.
- 2026-11-09 bootstrap design (next work, plan only): phases check, packages (sudo pacman: Java 21, git, curl, unzip, rustup, base-devel, `yay` only if absent; `yay` is in the `cachyos` repo), user toolchains (MVM, MatchBox 0.12.0, BVM, pinned BoxLang), binary (build with MatchBox from source, or accept a prebuilt file via `--binary PATH`), verify (`bxcachy version`, `bxcachy doctor`). Decisions: BoxLang pinned to an exact version (proposed 1.19.0, the current stable per downloads.ortussolutions.com on 2026-11-09); BVM and MVM install scripts are downloaded, shown and need the typed `EXECUTE` interactively, or `--allow-external-scripts` when unattended (plain `--yes` does not approve them); binary installs to `~/.local/bin/bxcachy`, never with sudo; reruns must finish partial installs and change nothing already done. Facts: the BVM installer embeds its own version (1.40.0 at the time of reading) and downloads helpers and a BoxLang installer zip from downloads.ortussolutions.com; the MVM installer honors `MVM_VERSION=x.y.z`, otherwise installs `latest`. Tasks B1 to B7 (check, plan output, BVM+BoxLang, yay/Rust/PATH, build+install binary, mock failure tests, real Arch container test incl. a no-change second run).
- 2026-11-09 bootstrap B1 and B2 implemented: `bootstrap/install.sh --check` now reports system (OS, CPU, root, sudo, free disk, network), packages (including `base-devel` and `yay`), tool versions against the pins (Java 21, MatchBox 0.12.0, BoxLang 1.19.0, MVM, BVM, Rust, bxcachy) and PATH; `--plan` prints the ordered steps still needed and runs nothing. `base-devel` was added to the package list. Mocked tests cover missing, present, wrong-version, root, unsupported-OS and bad-argument cases; the Arch container suite runs both modes for real. B3 to B7 not started.
- 2026-11-09 bootstrap B3 implemented: `install.sh --install-toolchains --yes [--allow-external-scripts]` is re-runnable and only does missing steps: MVM (external script), MatchBox 0.12.0 via `mvm install/use`, BVM (external script), BoxLang 1.19.0 via `bvm install/use`, each verified afterwards. External scripts are downloaded to a private cache directory (`~/.cache/bxcachy/external`, mode 700), shown with url, saved path, sha256 and the first 15 lines, and run only after a typed `EXECUTE` (interactive) or `--allow-external-scripts` (unattended); otherwise exit 2 and nothing runs. Real-system finding (Arch container, 2026-11-09): `bvm install 1.19.0` then `bvm use 1.19.0` puts BoxLang at `~/.bvm/bin/boxlang` reporting `v1.19.0+67`; the BVM installer is v1.40.0 and may add BVM to shell startup files. MVM/MatchBox could not be run in the authoring sandbox (GitHub blocked), so the full chain is verified only by CI stage 5. Rust (`rustup default stable`) and the binary build/install remain B4/B5.
- 2026-11-09 bootstrap B3 verified in CI (run 42553471974): all 31 stage-5 steps passed, including the real chain MVM, MatchBox 0.12.0, BVM, BoxLang 1.19.0, the no-op rerun, both pins and the native compile.
- 2026-11-09 bootstrap B4 implemented: `install.sh --install --yes` now refuses root, installs only the missing packages (no system upgrade on a rerun when nothing is missing), installs `yay` only if absent (from the configured repos, `cachyos` on CachyOS), activates Rust with `rustup default stable`, and prints, but does not apply, the PATH line for `~/.local/bin` (BxCachy does not edit shell startup files). At a terminal pacman shows its own transaction prompt; unattended, `--noconfirm` is passed because `--yes` already approved the plan. A real Arch run found that pacman's prompt blocked the unattended yay install; that is why. B5 (build and install the binary) to B7 remain.
- 2026-11-09 bootstrap B5 implemented: `install.sh --install-binary --yes [--binary PATH] [--force]` builds `src/bxcachy.bxs` with the pinned MatchBox in a throwaway directory (or takes an existing executable via `--binary`, rejecting symlinks, non-executables and anything that does not print `BxCachy ...` for `version`), verifies the result BEFORE touching the installed copy, then replaces `~/.local/bin/bxcachy` atomically (temp file in the same directory, then rename). A rerun with the same version prints "Nothing to do" (`--force` rebuilds); a failed build or failed self-check leaves the installed copy untouched. No sudo, refuses root. A test caught a version-regex bug (it matched the comment "BxCachy native CLI"). Real MatchBox builds are verified only by CI stage 5. B6 and B7 remain.
- 2026-11-09 bootstrap B6 implemented (failure paths): the installing modes now refuse early, with a reason, on an unsupported OS, a non-x86_64 CPU, or less than 5 GB free; `--install` needs sudo only when something must be installed; every toolchain step failure is named (`Failed: bvm install 1.19.0`); a dying external installer stops the run and a later run resumes. Mocked tests cover: network unreachable (reported, not fatal), unsupported OS, low disk, missing sudo, pacman failing (nothing else changed), rustup failing, an interrupted then resumed toolchain install, and a failing `bvm install`.

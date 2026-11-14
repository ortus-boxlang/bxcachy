---
title: Port status
order: 90
hidden: true
---

# BxRig migration status

## Milestone 1 — native foundation (not yet accepted)

Implemented on `development`:
- Native BoxLang CLI with `install --yes`, `optional-install NAME... --yes`, `profile-install NAME --yes`.
- Catalog validation, package detection, pacman-first/yay fallback, full repository preflight, root-user AUR guard, and nonzero failure exits.
- Mocked native integration tests for success, root rejection and unavailable packages.
- Single ordered CI pipeline with global cancellation and MatchBox 0.12.0 pin.

Still required before declaring milestone 1 complete:
- Verify successful CI execution of all native integration cases on the latest commit.
- Pin the MVM installer itself, BVM and BoxLang versions; provision and verify these on CachyOS (bootstrap currently provisions Java/Rust only).
- Reusable configuration-management service with backup, atomic replacement, idempotency and recovery tests.
- Installation recovery guidance: pacman and yay cannot provide a cross-manager atomic transaction. A failed AUR phase can leave official packages installed. Do not promise rollback without a tested implementation.
- Confirm actual native command execution and exit-code semantics on CachyOS, not just mocked Linux CI.

## Legacy migration remaining

Developer tools, KDE integration, AI/databases, containers/network/VM management, cloud, Quick Look, dictation, and first-run flows remain to be ported. The Python v0.10.0 release remains the functional reference until feature parity.

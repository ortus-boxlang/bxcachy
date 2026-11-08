# Native migration status

## Milestone 1: native foundation — in progress

The BoxLang CLI now implements catalog-validated install, optional-install, and profile-install with explicit --yes, installed-package detection, pacman-first/yay fallback, full availability preflight, root rejection for AUR, and subprocess exit-code handling. These are not yet validated against a successful MatchBox CI run.

**Limitations:** package installation is not transactionally atomic across pacman and yay; failures after pacman succeeds cannot be automatically rolled back. No general-purpose configuration management service is implemented. BVM/MVM/BoxLang/MatchBox installation remains unpinned. Automated tests cover argument rejection but do not yet mock and exercise successful native installs. Do not consider milestone 1 complete until CI and integration tests verify the implementation.

## Outstanding legacy migration

Developer tooling, cloud, dictation, Quick Look, KDE, databases, networking, VMs and GUI remain pending. The legacy Python implementation is the reference until feature parity is established.

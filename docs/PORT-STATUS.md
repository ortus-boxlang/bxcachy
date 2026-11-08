# Native port status

The current .bxs implementation ports the read-only app catalog from legacy bin/bxcachy-apps and the plan portion of legacy bin/bxcachy-dev.

Implemented: desktop-list, tui-list, web-list, optional-list, plan, apps-doctor (package list only), dev-plan, doctor, version, help.

Not implemented: actual pacman package state detection or installation, version management, cloud, dictation, Quick Look, desktop, database, network, VM, or GUI. Existing Python implementation remains the reference.

Native MatchBox compilation and smoke tests are not yet verified. Do not publish a production release until native compilation and feature-parity gates pass.

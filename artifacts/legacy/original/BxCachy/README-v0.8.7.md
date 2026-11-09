# BxCachy v0.8.7 — Expanded Omarchy 4.5 + Linux app catalog

The application catalog now includes Omarchy 4.5 newcomers (Hype, Signed, Disktree, Monologue, Gliff, Elsewhen, Omacut, Omasnap, Superwhisper), additional Linux desktop apps, terminal utilities, and web services.

The user-selected 29 catalog entries are marked as defaults. This **does not** automatically cause all of them to be installed by the first-run workflow; catalog default selection and installer orchestration are distinct.

New entries with unverified Arch packaging are marked `manual` and cannot be installed through an assumed package name. Use `app-manager list`, `search`, and `show` to inspect. Existing CachyOS, KDE, Hyprland, Noctalia configurations are untouched.

Omarchy reference: https://omarchy.org/news/2026/11/omarchy-4-5/

To review defaults: `./bin/bxcachy app-manager defaults`
To browse: `./bin/bxcachy app-manager gui`

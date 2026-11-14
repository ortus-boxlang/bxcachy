---
title: Troubleshooting
order: 10
summary: Doctors that print a fix for each problem.
---

# Troubleshooting

Start with `bxrig status` and the doctors; each prints a fix next to every failed check.

| Problem | Run |
|---|---|
| Something is missing after setup | `bxrig status`, then `bxrig init` |
| Installer failed | read `~/.cache/bxrig/install.log` |
| GPU or drivers | `bxrig gpu doctor` |
| Magic Mouse, Trackpad, Bluetooth | `bxrig input doctor` |
| Dolphin "Open with" is empty | `bxrig dolphin doctor --fix` |
| App launcher or menu | `bxrig runner doctor` |
| Containers | `bxrig containers doctor` |
| Shortcuts clash | `bxrig keys conflicts` |
| Plasma panels look wrong | `bxrig plasma panels undo --yes` |

## Exit codes

| Code | Meaning |
|---|---|
| 0 | done |
| 2 | a plan was printed (add `--yes`) or the usage was wrong |
| 4 | a precondition failed (a tool is missing, bad input) |
| 5, 6, 7 | a step failed (7: some steps done, some failed) |
| 9 | an internal error |
| 10 | `update check`: an update is available |

Add `--json` to any command for machine-readable output.


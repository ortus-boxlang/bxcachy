---
title: Troubleshooting
order: 10
summary: Doctors that print a fix for each problem.
---

# Troubleshooting

Start with `bxcachy status` and the doctors; each prints a fix next to every failed check.

| Problem | Run |
|---|---|
| Something is missing after setup | `bxcachy status`, then `bxcachy init` |
| Installer failed | read `~/.cache/bxcachy/install.log` |
| GPU or drivers | `bxcachy gpu doctor` |
| Magic Mouse, Trackpad, Bluetooth | `bxcachy input doctor` |
| Dolphin "Open with" is empty | `bxcachy dolphin doctor --fix` |
| App launcher or menu | `bxcachy runner doctor` |
| Containers | `bxcachy containers doctor` |
| Shortcuts clash | `bxcachy keys conflicts` |
| Plasma panels look wrong | `bxcachy plasma panels undo --yes` |

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

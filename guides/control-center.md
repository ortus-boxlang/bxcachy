---
title: Control Center
summary: One terminal for your whole machine, with a page for each job. Run bxcachy tui.
---

# Control Center

`bxcachy tui` opens one terminal screen with a list of pages on the left and the open page on the right.

```bash
bxcachy tui                   # opens on the Dashboard
bxcachy tui --demo            # made-up data, nothing is run
bxcachy tui dashboard --json  # the page's data, no terminal needed
```

## Keys

| Key | What it does |
|---|---|
| Tab, Shift+Tab (or `]`, `[`) | next and previous page |
| Left | move to the page list (Up and Down pick a page), Right or Enter goes back |
| q, Escape, Ctrl+c | leave |
| mouse | click a page or a row, scroll the wheel |

The key bar at the bottom shows the keys of the page you are on.

## Dashboard

The first page shows what needs your attention, then the state of the machine:

- **Needs attention:** updates waiting, a backup older than two days (or none yet), a disk over 85% full, a battery under 20%. Move to a line and press Enter, or press its key, to see the plan of the fix. Nothing changes until you press `y`.
- **System:** CPU load, memory, disk and battery.
- **Running:** your databases and VMs, with ports.
- **Backups:** how fresh each place is. Enter opens BxTimeMachine, and you come back to the Dashboard when you leave it.

Each part is read on its own. If one cannot be read, the rest still shows.

## How the pages fit together

Every screen shares one kit for lists, tabs, plan boxes and meters, so they look and behave the same. A page is a small class, which is also how new pages are added. A page can send you to a full screen such as BxTimeMachine and bring you back.

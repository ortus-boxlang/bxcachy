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

## Pages

| Page | What it does |
|---|---|
| Dashboard | what needs attention, meters, what runs, backups |
| BoxLang | BoxLang versions through `bvm`: use, install, remove |
| Java | your Java homes: default, remove, and `a` to browse every JDK SDKMAN offers and install one (see `bxcachy java`) |
| Maven | every Maven version SDKMAN offers, installed ones marked: install, default, remove (see `bxcachy sdk`) |
| Gradle | the same for Gradle |
| Versions | BoxLang, MatchBox, Java and Node in one table; Enter opens the deep page |
| Ports | what listens on which port and who owns it; stop or kill it, with a plan first. A port with two owners is red |
| Packages | search the repos and the AUR with `/`, then install or remove |
| Shortcuts | every shortcut; rebind (it asks for the keys), reset, conflicts |
| Machines | your VMs (Windows and Linux desktops in containers): start, stop, info, new |
| Databases | the databases BxCachy runs: start, stop, info, new |
| Storage | NAS shares and cloud remotes: mount, unmount, test |
| Secrets | names only; `v` shows one value for one look |
| Themes | the 15 themes; Enter applies |
| Logs | the journal of this boot; `p` changes the lowest priority shown |

In a table, `/` filters the rows (or searches, on Packages), Enter keeps it and Escape clears it. Every key that changes something shows a plan first.

## How the pages fit together

Every screen shares one kit for lists, tabs, plan boxes and meters, so they look and behave the same. A page is a small class, which is also how new pages are added. A page can send you to a full screen such as BxTimeMachine and bring you back.

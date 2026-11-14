---
title: Control Center
summary: One terminal for your whole machine, with a page for each job. Run bxrig tui.
---

# Control Center

`bxrig tui` opens one terminal screen with a list of pages on the left and the open page on the right.

```bash
bxrig tui                   # opens on the Dashboard, sidebar open
bxrig tui databases         # one page on its own, sidebar collapsed
bxrig tui list              # every page id and title (--json for scripts)
bxrig tui --demo            # made-up data, nothing is run
bxrig tui dashboard --json  # the page's data, no terminal needed
```

## One page at a time

`bxrig tui PAGE` opens that page alone, with the page list collapsed, so it feels like an app of its own: `bxrig tui databases`, `bxrig tui ports`, `bxrig tui mail`. An unknown page prints the list and exits 2. The top row shows where you are, `BXRIG › Databases`.

Open and close the page list with the backslash key or `Ctrl+b` (while a page is taking text, such as a filter, only `Ctrl+b` works). You can also click the thin strip at the left edge or the breadcrumb row, or press `Left`. Tab and Shift+Tab still change page. `--sidebar` and `--no-sidebar` force it either way. On a terminal narrower than 90 columns it starts collapsed so the page gets the room. BxRig does not remember the state: the next `bxrig tui` starts open again.

You can open any page without a terminal open first:

- **Menu:** `bxrig menu` has a Control Center section at the end. The first entry opens everything, then one entry per page. Each opens in your default terminal.
- **Application menu (optional):** `bxrig launchers on --yes` adds one entry per page ("BxRig Databases", with the BxRig icon) to a "BxRig" submenu of your application menu (menus without folders, like rofi, list them flat). `bxrig launchers status` shows them and `bxrig launchers off --yes` (or `bxrig remove launchers --yes`) takes them away. Entries you edited are kept. Nothing is added unless you ask.
- **Shortcuts:** every page has an unbound shortcut (`tui-databases`, ...). Give it keys with `bxrig keys set tui-databases Super+Alt+D --yes`, then `bxrig keys apply --yes`.

## Icons

The page list and page headers carry Nerd Font icons when your terminal has the font (the BxRig wizard installs one for Starship). They are on when a Nerd Font is found, and you can force them: `bxrig tui --icons=on` or `--icons=off`, or set `BXRIG_ICONS`. Without the font they would show as boxes, so BxRig leaves them off. Emoji are not used, because terminals draw them two cells wide and the tables would not line up.

## Keys

| Key | What it does |
|---|---|
| Tab, Shift+Tab (or `]`, `[`) | next and previous page |
| Left | move to the page list (Up and Down pick a page), Right or Enter goes back; with the list collapsed, Left opens it |
| `\`, Ctrl+b | collapse or open the page list |
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
| Apps | install, remove and update software: Installed, Discover and Updates tabs, a search box that is always there, icons and screenshots (see [Apps](apps.md#the-apps-manager)) |
| BoxLang | BoxLang versions through `bvm`: use, install, remove |
| Java | your Java homes: default, remove, and `a` to browse every JDK SDKMAN offers and install one (see `bxrig java`) |
| Maven | every Maven version SDKMAN offers, installed ones marked: install, default, remove (see `bxrig sdk`) |
| Gradle | the same for Gradle |
| Versions | BoxLang, MatchBox, Java and Node in one table; Enter opens the deep page |
| Ports | what listens on which port and who owns it; stop or kill it, with a plan first. A port with two owners is red |
| Packages | search the repos and the AUR with `/`, then install or remove |
| Shortcuts | every shortcut; rebind (it asks for the keys), reset, conflicts |
| Machines | your VMs (Windows and Linux desktops in containers): start, stop, info, new |
| Databases | the databases BxRig runs: start, stop, info, new |
| Mail | the mail your apps send to the catcher (`bxrig mail`): headers and text of the highlighted message, delete, clear, open it in the browser, send a test; it refreshes by itself every 3 seconds |
| Storage | NAS shares and cloud remotes: mount, unmount, test |
| Secrets | names only; `v` shows one value for one look |
| Themes | the 15 themes; Enter applies |
| Logs | the journal of this boot; `p` changes the lowest priority shown |

In a table, `/` filters the rows (or searches, on Packages), Enter keeps it and Escape clears it. Every key that changes something shows a plan first.

## How the pages fit together

Every screen shares one kit for lists, tabs, plan boxes and meters, so they look and behave the same. A page is a small class, which is also how new pages are added. A page can send you to a full screen such as BxTimeMachine and bring you back.

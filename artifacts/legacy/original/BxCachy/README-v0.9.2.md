# BxCachy v0.9.2 — independent launcher/menu backends

The runner abstraction now exposes **Rofi, Walker, Vicinae, and Hyprrunner** as selectable menu backends. Application launchers and BxCachy management menus are independent. No keyboard shortcuts are rewritten.

```sh
./bin/bxcachy runner set vicinae
./bin/bxcachy runner menu-set vicinae
./bin/bxcachy runner doctor
./bin/bxcachy menu

./bin/bxcachy runner set hyprrunner
./bin/bxcachy runner menu-set hyprrunner
./bin/bxcachy runner doctor
./bin/bxcachy menu
```

**Compatibility warning:** the default `vicinae dmenu --prompt ...` and `hyprrunner --dmenu` commands are **provisional**; availability and CLI flags must be confirmed against the installed version. These providers now have complete selection/index handling, but native extension protocols have not been verified. Override the argv without editing code:

```sh
./bin/bxcachy runner menu-command vicinae vicinae dmenu --prompt '{prompt}'
./bin/bxcachy runner menu-command hyprrunner hyprrunner --dmenu
./bin/bxcachy runner launcher-command vicinae vicinae toggle
```

The runner invokes subprocesses using argv (not a shell) and reports unavailable executables. The BxCachy menu's Phosphor icon metadata is used by Rofi; other providers receive clean labels. Existing `Super + Space`, KDE, Hyprland, and Noctalia configuration are untouched. If your version of Vicinae/Hyprrunner does not expose a dmenu-compatible CLI, use Rofi or Walker for management menus until a native extension is built and tested.

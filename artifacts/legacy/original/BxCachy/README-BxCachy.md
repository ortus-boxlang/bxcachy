# BxCachy — CachyOS workstation customization toolkit (preview 0.5)

BxCachy builds on the earlier CachyOS Omarchy compatibility pack. It is **not** the official Omarchy distribution. It keeps KDE Plasma intact and provides optional Hyprland/Noctalia tooling, package groups, a Rofi-wayland graphical management menu, themes, and separate shortcuts.

## Quick start

```bash
unzip BxCachy-v0.5-preview.zip
cd BxCachy
./bin/bxcachy runner show
./bin/bxcachy provision plan
./bin/bxcachy shortcuts list
./bin/bxcachy shortcuts generate
./bin/desktop-install --install-deps  # CachyOS/Arch only; installs rofi-wayland and ghostty
./bin/bxcachy menu                # requires running graphical session + rofi
```

## Runner portability

Config: `~/.config/bxcachy/config.json`, initialized by `./bin/bxcachy runner set PROVIDER`. Providers: `system`, `noctalia`, `rofi`, `walker`, `krunner`, `custom`. `system` is the default and intentionally does not execute or override any desktop launcher. It preserves your current Hyprland `Super+Space` runner. Use `runner doctor` to inspect. `custom_command` is a JSON argv array; no shell expansion.

## Shortcut configuration

Edit via `./bin/bxcachy shortcuts edit`, or `./bin/bxcachy shortcuts gui` when Rofi is available. JSON: `~/.config/bxcachy/shortcuts.json`. Generated include: `~/.config/hypr/bxcachy-keys.conf`. Only **Super+Alt+Space** for BxCachy is included by default; it is **not activated**. After reviewing conflicts, manually source the file in a traditional Hyprland config. CachyOS Lua-managed Hyprland configs need their own integration. KDE shortcuts are never touched.

## Extensible menu

Graphical menu: `./bin/bxcachy menu` (Rofi). User overrides: `~/.config/bxcachy/menu.json`, based on `menu/default.json`. Terminal menu remains at `./bin/omarchy-menu`. Menu entries are argv arrays, not shell commands.

## Safety and limitations

Provisioning is the earlier v0.4 implementation and has not been verified on a real CachyOS desktop. It may install packages when explicitly invoked; use `provision plan` first. GUI needs a running Wayland session. The theme manager is an earlier prototype; do not assume pixel-perfect Omarchy/Noctalia theme parity. Shortcut conflict detection only checks BxCachy-owned shortcuts, not all Hyprland config includes. No KDE, SDDM, bootloader, or system settings are intentionally modified by the menu/shortcut commands. Back up configs and review any installer before running.

## Test coverage

Run `python -m unittest discover -s tests -v`. The original v0.4/v0.5 tests are archived under `tests/legacy/` because they assert the old package name and paths; v0.4 provisioning tests additionally require an unprivileged account. Do not treat this as validation of live desktop installation.

## v0.5.1: Tiled and floating window modes

- `./bin/bxcachy layout window toggle` toggles the focused window (Hyprland `togglefloating`).
- `./bin/bxcachy layout workspace toggle` toggles all windows on the **active workspace**: if all are floating, tiles them; otherwise floats any tiled windows. Mixed workspaces are normalized to floating on first toggle.
- Explicit commands: `layout window float|tile`, `layout workspace float|tile`.
- Graphical menu: **Window Management** section, including toggle and explicit mode actions.
- Default managed bindings: `SUPER+V` for focused window; `SUPER+ALT+V` for workspace. Customize with `./bin/bxcachy shortcuts gui` or `./bin/bxcachy shortcuts set toggle-window-layout SUPER V`.
- **Important:** BxCachy only generates bindings. To activate them, run `./bin/bxcachy shortcuts generate`, review conflicts with existing Hyprland shortcuts, then add `source = ~/.config/hypr/bxcachy-keys.conf` to your traditional Hyprland configuration. Lua-based configurations require manual integration. No KDE bindings are changed.
- This controls *floating vs tiled* window state; it does not replace Hyprland's tiling layout engine or provide KDE-style minimize/maximize/title bars. `hyprctl` and an active Hyprland session are required.
- Existing user-owned `~/.config/bxcachy/shortcuts.json` is not overwritten. To add new defaults, merge the two new entries from `config/shortcuts.json` manually or run `./bin/bxcachy shortcuts reset` **only if you want to replace your custom BxCachy shortcuts**.

## Podman installation (v0.5.2)

The Install menu now offers **Podman + supporting tools**. This is opt-in and does not replace Docker, install a Docker alias, or alter KDE.

```bash
./bin/bxcachy podman plan
./bin/bxcachy podman install
./bin/bxcachy podman doctor
./bin/bxcachy podman socket-enable  # optional rootless API
./bin/bxcachy podman compose-check
```

The pacman-first manifest includes Podman, conmon, crun, containers-common, passt, slirp4netns, fuse-overlayfs, netavark, aardvark-dns, Buildah, Skopeo, podman-compose, and shadow. All packages must resolve in configured repositories before installation; unknown packages fail safely. Package availability depends on current CachyOS repositories.

**Btrfs note:** If Podman reports an overlay storage backing-filesystem error, inspect `podman info` and `~/.config/containers/storage.conf` before changing storage. This installer intentionally does not overwrite storage configuration. Windows VM support remains a separate planned installer and is not installed by this action.


## v0.5.3 JVM / BoxLang development tools

BxCachy includes separate installers for SDKMAN!, OpenJDK 21 (or a selected supported JDK version), Maven, Gradle, BoxLang Quick Installer, BVM, and MatchBox MVM. Menu: **Install** or **JVM & BoxLang**.

```bash
./bin/bxcachy dev plan all
./bin/bxcachy dev install java --java-version 21
./bin/bxcachy dev install maven
./bin/bxcachy dev install gradle
./bin/bxcachy dev install sdkman --yes
./bin/bxcachy dev install boxlang --yes
./bin/bxcachy dev install bvm --yes
./bin/bxcachy dev install mvm --yes
./bin/bxcachy dev version bvm install latest
./bin/bxcachy dev version mvm install latest
./bin/bxcachy dev doctor all
```

Remote installer scripts are downloaded from official upstream endpoints to a temporary file and **require a second typed `EXECUTE` confirmation** before execution. `--dry-run` never installs. `pacman` installs Java/Maven/Gradle; no automatic change to system Java default or shell profile. SDKMAN!, BVM, and MVM can update shell initialization through their own upstream installers. BVM and the single-version BoxLang Quick Installer may overlap; choose one for runtime version management. After installing SDKMAN!, restart your shell or source its init script.

Upstream references: https://sdkman.io/install , https://boxlang.io/download/ , https://github.com/ortus-boxlang/matchbox-quick-installer

## v0.5.4 Phosphor icon integration

BxCachy graphical menu now passes Phosphor icon names or cached official SVG paths to Rofi using its icon protocol. Every bundled section and action has an icon identifier, including SDKMAN, Java, Maven, Gradle, BoxLang, BVM, MVM, Podman, and window management. Native application runner remains desktop-owned; BxCachy does **not** replace the icons or behavior of your existing Hyprland runner.

```bash
./bin/bxcachy icons list
./bin/bxcachy icons sync   # download official Phosphor Regular SVGs; internet required
./bin/bxcachy icons doctor
./bin/bxcachy menu
```

Icons are cached locally, so the graphical menu works offline after sync. Without sync, Rofi attempts to resolve icon-theme names and remains functional with text labels. The upstream Phosphor SVGs are not bundled in this archive because the build environment cannot retrieve them. See `icons/README.md` for licensing/source.

Custom menu entries may use `"icon": "terminal-window"` or another Phosphor Regular asset name. Add the icon to the default menu or download the matching SVG to `~/.local/share/bxcachy/icons/phosphor/regular/`. Existing user-defined menu sections are merged by ID with built-in defaults.

**Installation safety:** Remote BoxLang/SDKMAN/MVM installers still require explicit review and confirmation. The Windows VM is still planned, not yet installed by BxCachy.

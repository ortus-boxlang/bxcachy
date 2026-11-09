# BxCachy v0.8 — development build

Designed to **augment** an existing CachyOS Hyprland + Noctalia desktop. Does not reinstall either, replace the application runner, or change KDE. This is not a hardware-validated release.

## Implemented in this iteration

- Claude Code official script: fetch to temporary directory, show SHA256 and preview, require explicit `EXECUTE` confirmation. Not checksum-pinned; review upstream script before proceeding.
- LM Studio: official download instructions and existing `lms` CLI management. **No automated LM Studio AppImage installer** because a verified versioned Linux distribution URL has not been integrated.
- AI console: special-workspace toggle now opens the workspace after launching Ghostty; tmux sessions and agent selection remain. Requires live Hyprland validation.
- Shortcut conflict scan: `bxcachy shortcuts conflicts` scans statically included traditional Hyprland configs; dynamic/Lua bindings cannot be reliably scanned. Activation blocks on detected conflicts. The current default Super+Space runner remains untouched.
- Desktop utilities: optional pacman installation groups for clipboard, screenshots, recording, wallpaper, monitor, audio, Bluetooth. Commands for clipboard, screenshot, and recording. No automatic desktop service startup.
- Themes: generate opt-in Ghostty and Hyprland fragments plus a Noctalia color reference. **Not complete Noctalia theme synchronization.**
- Developer tools: existing SDKMAN, Java, Maven, Gradle, BoxLang, BVM and MatchBox installers preserved; live installer verification outstanding.
- Windows VM: resource and port validation; refuses creating a container with an existing name. Persistent data remains protected. Rootless KVM and boot remain unverified.
- Profiles: export and preview/import a restricted allowlist of user configuration JSON with backups. No automatic desktop activation.
- Rollback: rejects snapshots outside the trusted BxCachy state directory.

## Usage

```sh
./bin/bxcachy ai install claude --dry-run
./bin/bxcachy ai install lmstudio --dry-run
./bin/bxcachy ai dropdown
./bin/bxcachy shortcuts conflicts
./bin/bxcachy desktop plan all
./bin/bxcachy theme list
./bin/bxcachy theme generate tokyo-night
./bin/bxcachy vm plan
./bin/bxcachy profile export /tmp/my-bxcachy.json
./bin/bxcachy profile import /tmp/my-bxcachy.json
python -m unittest discover -s tests -v
```

## Known limitations

This release is not feature-complete for all nine goals. LM Studio installation is guided rather than automated; Noctalia theme application, clipboard history daemon integration, a full GUI settings panel, external installer pinning, Windows VM real boot, and desktop shortcut testing require further work. Avoid enabling the generated Hyprland shortcut include without reviewing the results of `shortcuts conflicts` and your actual active bindings.

## Default base JVM tools (v0.8.1)

BxCachy's recommended base profile includes Java 21 (`jdk21-openjdk`), BoxLang Version Manager (`bvm`), and MatchBox Version Manager (`mvm`). Run `./bin/bxcachy base plan` to preview, `./bin/bxcachy base doctor` to inspect, and `./bin/bxcachy base install --yes` to install missing components. BVM and MVM download third-party installation scripts and require a second interactive `EXECUTE` confirmation before execution. Java 21 is installed alongside other JDKs; the system default is not changed unless `--set-java-default` is explicitly supplied. SDKMAN, Maven, Gradle and additional JDKs remain optional.

## Omarchy-inspired base profile (v0.8.2)

The standard `bxcachy base install --yes` now installs **both** the Omarchy-inspired
base packages and Java 21/BVM/MVM. Preview with `bxcachy base plan` and check
with `bxcachy base doctor`. To install just the JVM trio, pass `--skip-omarchy`.
The Omarchy package group includes Git, GitHub CLI, Lazygit, fzf, zoxide,
ripgrep, fd, eza, bat, btop, Starship, tmux, jq, curl, gum, Neovim,
Rofi Wayland, Ghostty, and clipboard/screenshot/recording utilities.
These are **Omarchy-inspired defaults**, not a byte-for-byte reproduction of
Omarchy's upstream package manifest. No LazyVim configuration is applied;
Neovim is installed without overwriting existing editor configuration.
No desktop services or Hyprland keybindings are enabled automatically.
No KDE, Noctalia, Hyprland, or existing runner packages are replaced.

## v0.8.3 additions (base install)

- LazyVim starter installed into `~/.config/nvim` **only if the path does not exist**; existing Neovim configs are preserved. LazyVim plugins are fetched when Neovim launches.
- Wayland clipboard (`wl-clipboard`, `cliphist`), screenshots (`grim`, `slurp`, `swappy`) and recording (`wf-recorder`) are in the Omarchy-inspired base package set. `bxcachy desktop clipboard-service enable` enables clipboard history capture using a user systemd service; leave disabled if Noctalia already captures history.
- Podman, Buildah, Skopeo, Podman Compose, and rootless storage/network dependencies are in the base installation.
- Docker-compatible `docker` and `docker-compose` wrappers are created in `~/.local/bin` only when there is no existing command or conflicting file. These map to `podman` and `podman-compose` respectively; they do not provide full Docker Engine compatibility. Make sure `~/.local/bin` is on PATH.
- Rootless API socket is **opt-in**: `bxcachy podman socket-enable`; for Docker API clients, set `DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock`.
- Existing KDE, Hyprland, Noctalia and application runner configurations remain untouched.

Commands: `bxcachy base plan`, `bxcachy base install --yes`, `bxcachy base doctor`, `bxcachy extras doctor`, `bxcachy desktop clipboard-service enable`.

No installation or live Hyprland integration has been tested on CachyOS. Some third-party tools may require Docker Engine-specific functionality and are not guaranteed to work through Podman wrappers.

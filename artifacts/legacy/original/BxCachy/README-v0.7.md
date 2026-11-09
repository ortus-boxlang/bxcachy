# BxCachy v0.7 — AI Workstation preview

Adds AI console and installer catalog on top of existing CachyOS + Hyprland + Noctalia. KDE and the existing application runner are untouched.

## AI console

- `./bin/bxcachy ai doctor` — discover installed CLIs
- `./bin/bxcachy ai console` — choose installed agent (Rofi or terminal)
- `./bin/bxcachy ai set codex` — configure default agent
- `./bin/bxcachy ai launch codex` — run selected CLI in current terminal
- `./bin/bxcachy ai dropdown` — toggle a dedicated Hyprland special workspace containing a Ghostty AI console
- Default shortcut: **Super + Alt + A**, staged in `config/shortcuts.json`; run `./bin/bxcachy shortcuts generate` and explicitly source generated bindings from Hyprland. Check conflicts before activation.

## Installers

`./bin/bxcachy ai install codex|opencode|gemini` uses npm (requires Node/npm and write permissions to npm global prefix). Claude Code and Ollama report official upstream install URLs instead of automatically executing unverified remote shell scripts. Installer support for those two is **not complete**. No API keys are requested or stored.

## Limitations

- Hyprland special workspace behavior and Ghostty class flags require live CachyOS testing.
- This is a dropdown *workspace*, not an animated top-edge Quake terminal.
- Existing Hyprland binds may conflict with Super+Alt+A; use shortcut editor to change it.
- AI console requires an installed AI CLI; no model management or provider settings yet.
- `bxcachy ai dropdown` assumes Ghostty and a Hyprland session.

## AI update: v0.7.1

- LM Studio is supported via the official Linux application and its `lms` CLI. The app itself is **not silently downloaded**: run `bxcachy ai install lmstudio` to see the official download URL, install the AppImage, and verify `lms` is on PATH.
- `bxcachy ai lmstudio list|loaded|server-start|server-stop|get MODEL|load MODEL|unload MODEL` wraps LM Studio's CLI.
- `bxcachy ai models list|running|pull MODEL|remove MODEL` manages Ollama models.
- `bxcachy ai install ollama --dry-run` previews the official Arch package installation using pacman; installation requires confirmation.
- `bxcachy ai persistent on` enables tmux-based agent session reuse inside the AI console when tmux is installed.
- `bxcachy ai size 80 75` and `bxcachy ai rules` generate opt-in floating, centered Hyprland window rules. Source `~/.config/bxcachy/generated/ai-window-rules.conf` in `hyprland.conf` to enable. Check Hyprland syntax against your installed version first.
- Your existing Super+Space runner is never changed.

**Limitations:** Claude Code and LM Studio still require official interactive/manual installation. Live Hyprland dropdown behavior, `lms` CLI compatibility, and external package installations remain unverified on a CachyOS host.

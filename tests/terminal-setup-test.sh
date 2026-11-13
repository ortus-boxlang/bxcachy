#!/usr/bin/env bash
# `bxcachy setup terminal` and the default terminal in `setup hyprland`, with fake pacman, sudo, id. Usage: terminal-setup-test.sh [binary]
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home"
export LOG="$tmp/log"; : > "$LOG"
cat > "$tmp/bin/pacman" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  -Q) exit 1 ;;
  -Qq) true ;;
  -S) echo "pacman $*" >> "$LOG" ;;
  --version) echo "Pacman v7.0" ;;
  *) exit 9 ;;
esac
MOCK
printf '#!/usr/bin/env bash\n[[ "$1" == --version ]] && { echo "Sudo version 1.9"; exit 0; }\n"$@"\n' > "$tmp/bin/sudo"
printf '#!/usr/bin/env bash\nif [[ "$1" == -u ]]; then echo "${MOCK_UID:-1000}"; else /usr/bin/id "$@"; fi\n' > "$tmp/bin/id"
printf '#!/usr/bin/env bash\necho x86_64\n' > "$tmp/bin/uname"
chmod +x "$tmp/bin/"*
printf 'ID=cachyos\n' > "$tmp/os"
run() { env BXCACHY_OS_RELEASE="$tmp/os" BXCACHY_STATE_HOME="$tmp/state" BXCACHY_CONFIG_HOME="$tmp/cfg" HOME="$tmp/home" USER=dev PATH="$tmp/bin:$PATH" XDG_CURRENT_DESKTOP=Hyprland LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

[[ "$(code "$binary" setup terminal)" == 2 ]] || fail 'no --yes exits 2'
run "$binary" setup terminal --dry-run --json | jq -e '.ok and (.data.steps[0].commands[0] | join(" ") | test("ghostty$"))' >/dev/null || fail 'ghostty is the default terminal'
[[ "$(code "$binary" setup terminal --default=putty --yes)" == 4 ]] || fail 'an unknown terminal exits 4'
[[ "$(code "$binary" setup terminal --also=putty --yes)" == 4 ]] || fail 'an unknown extra exits 4'

# default plus extras: packages in one call, a font config for each that has one; user files are kept
mkdir -p "$tmp/cfg/kitty"; echo 'mine' > "$tmp/cfg/kitty/kitty.conf"
run "$binary" setup terminal --also=kitty,foot,konsole --yes --json | jq -e '.ok and (.data.done | map(.id) == ["packages","config"])' >/dev/null || fail 'setup terminal --yes'
grep -q 'pacman -S --needed --noconfirm ghostty kitty foot konsole' "$LOG" || fail 'all four packages in one call'
grep -q 'font-family = JetBrainsMono Nerd Font' "$tmp/cfg/ghostty/config" || fail 'ghostty font written'
grep -q 'font=JetBrainsMono Nerd Font' "$tmp/cfg/foot/foot.ini" || fail 'foot font written'
[[ "$(cat "$tmp/cfg/kitty/kitty.conf")" == mine ]] || fail 'existing kitty.conf was overwritten'
grep -q "config-file = ?$tmp/cfg/bxcachy/theme/ghostty" "$tmp/cfg/ghostty/config" || fail 'ghostty includes the theme file'
grep -q "include=$tmp/cfg/bxcachy/theme/foot.ini" "$tmp/cfg/foot/foot.ini" || fail 'foot includes the theme file'
[[ -s "$tmp/cfg/bxcachy/theme/ghostty" && -s "$tmp/cfg/bxcachy/theme/foot.ini" && -s "$tmp/cfg/bxcachy/theme/kitty.conf" ]] || fail 'the default theme files exist so the includes never point at nothing'
[[ ! -e "$tmp/cfg/konsole" ]] || fail 'konsole has no starter config'

# hyprland uses the chosen terminal on Super+Enter and installs it instead of the default
rm -rf "$tmp/cfg"
run "$binary" setup hyprland --terminal=alacritty --yes >/dev/null || fail 'setup hyprland --terminal'
grep -q 'local terminal    = "alacritty"' "$tmp/cfg/hypr/hyprland.lua" || fail 'hyprland.lua uses the chosen terminal'
grep -q 'pacman -S --needed --noconfirm .*alacritty' "$LOG" || fail 'chosen terminal installed with hyprland'
rm -rf "$tmp/cfg"; run "$binary" setup hyprland --yes >/dev/null || fail 'setup hyprland'
grep -q 'local terminal    = "ghostty"' "$tmp/cfg/hypr/hyprland.lua" || fail 'ghostty is the default on Super+Enter'
[[ "$(code "$binary" setup hyprland --terminal=putty --yes)" == 4 ]] || fail 'an unknown terminal exits 4'
# window layout in the starter hyprland.lua
lua() { rm -rf "$tmp/cfg"; run "$binary" setup hyprland "$@" --yes >/dev/null || fail "setup hyprland $*"; cat "$tmp/cfg/hypr/hyprland.lua"; }
l="$(lua)"; grep -q 'layout           = "dwindle"' <<<"$l" || fail 'dwindle is the default layout'; ! grep -q '^hl.window_rule({ name = "bxcachy-floating"' <<<"$l" || fail 'tiling must not float windows'
l="$(lua --layout=master)"; grep -q 'layout           = "master"' <<<"$l" || fail 'master layout'
l="$(lua --layout=scrolling)"; grep -q 'layout           = "scrolling"' <<<"$l" || fail 'scrolling layout'
l="$(lua --layout=floating)"; grep -q 'layout           = "dwindle"' <<<"$l" && grep -q '^hl.window_rule({ name = "bxcachy-floating", match = { class = ".\*" }, float = true })' <<<"$l" || fail 'floating keeps dwindle underneath and floats new windows'
[[ "$(code "$binary" setup hyprland --layout=carousel --yes)" == 4 ]] || fail 'an unknown layout exits 4'
# the other starter choices: workspaces, natural scroll, keyboard layouts, theme, wallpaper
l="$(lua)"; grep -q 'workspace = "4", persistent' <<<"$l" && ! grep -q 'workspace = "5", persistent' <<<"$l" || fail 'four workspaces by default'
grep -q 'natural_scroll = false' <<<"$l" && grep -q 'kb_layout    = "us",' <<<"$l" && ! grep -q 'kb_options' <<<"$l" || fail 'defaults: traditional scroll, one US layout'
grep -q 'mode = "dark"' "$tmp/cfg/noctalia/config.toml" && grep -q 'path = ".*/box.jpg"' "$tmp/cfg/noctalia/config.toml" || fail 'defaults: dark theme, box wallpaper'
l="$(lua --workspaces=4 --natural-scroll --layouts=us-intl,es --theme=light --wallpaper=minimal)"
grep -q 'workspace = "4", persistent' <<<"$l" && ! grep -q 'workspace = "5", persistent' <<<"$l" || fail '4 workspaces'
grep -q 'natural_scroll = true' <<<"$l" || fail 'natural scroll on'
grep -q 'kb_layout    = "us,es",' <<<"$l" && grep -q 'kb_variant   = "intl,",' <<<"$l" && grep -q 'kb_options   = "grp:alt_shift_toggle",' <<<"$l" || fail 'US international and Spanish layouts with Alt+Shift'
grep -q 'mode = "light"' "$tmp/cfg/noctalia/config.toml" && grep -q 'path = ".*/minimal.png"' "$tmp/cfg/noctalia/config.toml" || fail 'light theme, minimal wallpaper'
for bad in --workspaces=0 --workspaces=11 --layouts=xx --theme=pink --wallpaper=none; do [[ "$(code "$binary" setup hyprland "$bad" --yes)" == 4 ]] || fail "$bad should exit 4"; done
echo "terminal setup tests passed"

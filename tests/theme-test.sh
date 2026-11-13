#!/usr/bin/env bash
# `bxcachy theme list|show|set|mode|status|random|next` with fake desktop tools. Usage: theme-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/state"; export LOG="$tmp/log"; : > "$LOG"
logger() { printf '#!/usr/bin/env bash\necho "%s $*" >> "$LOG"\n%s\n' "$1" "${2:-}" > "$tmp/bin/$1"; }
for t in noctalia plasma-apply-colorscheme hyprctl; do logger $t; done
chmod +x "$tmp/bin"/*
run() { env HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

# list: 15 bundled themes, both origins, nothing current yet
run "$binary" theme list --json | jq -e '.ok and (.data.themes | length == 15) and (.data.themes | map(select(.valid)) | length == 15) and (.data.themes | map(select(.light)) | map(.name) | sort == ["bxcachy-light","catppuccin-latte","flexoki-light","rose-pine"])' >/dev/null || fail 'list'
run "$binary" theme show bxcachy | grep -q 'accent #00ff78' || fail 'show'
[[ "$(code "$binary" theme show nope)" == 4 ]] || fail 'unknown theme exits 4'
[[ "$(code "$binary" theme set nope)" == 4 ]] || fail 'set unknown exits 4'
[[ "$(code "$binary" theme set bxcachy --mode=purple)" == 2 ]] || fail 'bad mode exits 2'
[[ "$(code "$binary" theme)" == 2 ]] || fail 'usage exits 2'

# dry run changes nothing
run "$binary" theme set catppuccin --dry-run --json | jq -e '.dry_run and (.data.files | length == 8)' >/dev/null || fail 'dry run plan'
[[ ! -e "$tmp/cfg" ]] || fail 'dry run wrote files'

# set a dark theme: files, then the desktop is told
run "$binary" theme set catppuccin >/dev/null
for f in noctalia/palettes/BxCachyTheme.json bxcachy/theme/ghostty bxcachy/theme/kitty.conf bxcachy/theme/alacritty.toml bxcachy/theme/foot.ini bxcachy/theme/hypr.lua btop/themes/bxcachy.theme; do [[ -s "$tmp/cfg/$f" ]] || fail "missing $f"; done
[[ -s "$tmp/state/bxcachy/current/theme/neovim.lua" ]] && grep -q 'catppuccin-mocha' "$tmp/state/bxcachy/current/theme/neovim.lua" || fail 'neovim.lua for the current theme'
jq -e '.version == 2 and .dark.primary == "#89b4fa" and .light.surface == "#1e1e2e"' "$tmp/cfg/noctalia/palettes/BxCachyTheme.json" >/dev/null || fail 'palette content'
grep -q 'background = #1e1e2e' "$tmp/cfg/bxcachy/theme/ghostty" && grep -q '^palette = 15=#cdd6f4' "$tmp/cfg/bxcachy/theme/ghostty" || fail 'ghostty content'
grep -q 'rgba(89b4faee)' "$tmp/cfg/bxcachy/theme/hypr.lua" || fail 'hypr accent'
grep -q 'noctalia msg color-scheme-set custom BxCachyTheme' "$LOG" && grep -q 'noctalia msg theme-mode-set dark' "$LOG" || fail "noctalia: $(cat "$LOG")"
! grep -q 'plasma-apply-colorscheme' "$LOG" || fail 'plasma only on KDE'
jq -e '.name == "catppuccin" and .mode == "theme"' "$tmp/cfg/bxcachy/theme.json" >/dev/null || fail 'state file'

# the same theme again: nothing rewritten; a light theme sets light; KDE gets Breeze; Hyprland reloads
run "$binary" theme set catppuccin --json | jq -e '(.data.written | length == 0) and (.data.unchanged | length == 8)' >/dev/null || fail 'second set is a no-op'
: > "$LOG"; XDG_CURRENT_DESKTOP=KDE HYPRLAND_INSTANCE_SIGNATURE=x run "$binary" theme set catppuccin-latte --json | jq -e '.data.applied_mode == "light" and .data.plasma == "applied" and .data.hyprland == "reloaded"' >/dev/null || fail 'light theme on KDE and Hyprland'
grep -q 'noctalia msg theme-mode-set light' "$LOG" && grep -q 'plasma-apply-colorscheme BreezeLight' "$LOG" && grep -q 'hyprctl reload' "$LOG" || fail "light: $(cat "$LOG")"

# bundled BxCachy themes bring a wallpaper (only when the file exists); --keep-wallpaper skips it
mkdir -p "$tmp/home/Pictures/BxCachy"; : > "$tmp/home/Pictures/BxCachy/aurora.jpg"; : > "$LOG"
run "$binary" theme set bxcachy-cyan >/dev/null; grep -q "noctalia msg wallpaper-set $tmp/home/Pictures/BxCachy/aurora.jpg" "$LOG" || fail "wallpaper: $(cat "$LOG")"
: > "$LOG"; run "$binary" theme set bxcachy-cyan --keep-wallpaper >/dev/null; ! grep -q wallpaper-set "$LOG" || fail 'keep wallpaper'

# mode: pinned, auto, back to the theme's own
: > "$LOG"; run "$binary" theme mode light >/dev/null; grep -q 'noctalia msg theme-mode-set light' "$LOG" || fail 'mode light'
run "$binary" theme mode auto >/dev/null; grep -q 'theme-mode-set auto' "$LOG" || fail 'mode auto'
jq -e '.mode == "auto" and .name == "bxcachy-cyan"' "$tmp/cfg/bxcachy/theme.json" >/dev/null || fail 'mode kept in state'
run "$binary" theme set catppuccin >/dev/null; jq -e '.mode == "auto"' "$tmp/cfg/bxcachy/theme.json" >/dev/null || fail 'a pinned mode survives set'
run "$binary" theme mode theme >/dev/null; jq -e '.mode == "theme"' "$tmp/cfg/bxcachy/theme.json" >/dev/null || fail 'mode theme'
[[ "$(code "$binary" theme mode sideways)" == 2 ]] || fail 'bad mode value'

# status, next, random
run "$binary" theme status --json | jq -e '.data.name == "catppuccin" and (.data.files | map(select(.state == "clean")) | length == 8)' >/dev/null || fail 'status'
run "$binary" theme next --json | jq -e '.ok and .data.theme != "catppuccin"' >/dev/null || fail 'next'
before="$(jq -r .name "$tmp/cfg/bxcachy/theme.json")"; run "$binary" theme random >/dev/null; [[ "$(jq -r .name "$tmp/cfg/bxcachy/theme.json")" != "$before" ]] || fail 'random picks another theme'

# Noctalia absent: files still written, the note says so
mv "$tmp/bin/noctalia" "$tmp/noctalia.off"
run "$binary" theme set nord --json | jq -e '.ok and .data.noctalia == "skipped"' >/dev/null || fail 'no noctalia is not an error'
mv "$tmp/noctalia.off" "$tmp/bin/noctalia"

# a theme found on disk (Omarchy user folder) beats a bundled one with the same name and works in the named-colour format
mkdir -p "$tmp/cfg/omarchy/themes/mine/backgrounds"
cat > "$tmp/cfg/omarchy/themes/mine/colors.toml" <<'TOML'
mode = "light"
accent = "#112233"
background = "#fafafa"
foreground = "#202020"
red = "#d00000"
green = "#00a000"
yellow = "#c0a000"
blue = "#0000d0"
magenta = "#a000a0"
cyan = "#00a0a0"
TOML
: > "$tmp/cfg/omarchy/themes/mine/backgrounds/1.png"
run "$binary" theme list --json | jq -e '.data.themes | map(select(.name == "mine" and .origin == "omarchy" and .light)) | length == 1' >/dev/null || fail 'omarchy theme on disk is listed'
: > "$LOG"; run "$binary" theme set mine --json | jq -e '.data.applied_mode == "light"' >/dev/null || fail 'set an Omarchy theme'
grep -q "wallpaper-set $tmp/cfg/omarchy/themes/mine/backgrounds/1.png" "$LOG" || fail 'its own backgrounds are used'
echo "accent = nope" > "$tmp/cfg/omarchy/themes/mine/colors.toml"
[[ "$(code "$binary" theme set mine)" == 4 ]] || fail 'an invalid theme is rejected before anything is written'
echo "theme tests passed"

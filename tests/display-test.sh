#!/usr/bin/env bash
# `bxrig display ...` with fake hyprctl, kscreen-doctor, brightnessctl and noctalia. Usage: display-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home"; export LOG="$tmp/log"; : > "$LOG"
cat > "$tmp/mons.json" <<'J'
[{"name":"eDP-1","description":"Laptop","width":2880,"height":1800,"refreshRate":120.0,"x":0,"y":0,"scale":1.5,"transform":0,"focused":true,"disabled":false},
 {"name":"DP-2","description":"Dell","width":2560,"height":1440,"refreshRate":59.95,"x":1920,"y":0,"scale":1.0,"transform":1,"focused":false,"disabled":false}]
J
cat > "$tmp/bin/hyprctl" <<'F'
#!/usr/bin/env bash
echo "hyprctl $*" >> "$LOG"
[[ "$1" == monitors ]] && cat "$MONS"
exit 0
F
for t in kscreen-doctor brightnessctl noctalia; do printf '#!/usr/bin/env bash\necho "%s $*" >> "$LOG"\n' "$t" > "$tmp/bin/$t"; done
chmod +x "$tmp/bin"/*
run() { env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" PATH="$tmp/bin:$PATH" LOG="$LOG" MONS="${MONS:-$tmp/mons.json}" "$@"; }
hypr() { run env HYPRLAND_INSTANCE_SIGNATURE=x "$@"; }
plasma() { run env XDG_CURRENT_DESKTOP=KDE "$@"; }
code() { set +e; hypr "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
has() { grep -qF -- "$1" "$LOG"; }
mon="$tmp/cfg/bxrig/theme/monitors.lua"
monhas() { grep -qF -- "$1" "$mon"; }

hypr "$binary" display list --json | jq -e '(.data.monitors | length == 2) and .data.monitors[0].internal and (.data.monitors[1].rotation == 90)' >/dev/null || fail 'list reads hyprctl monitors'
[[ "$(code "$binary" display nonsense)" == 2 ]] || fail 'usage exits 2'

# ---- scale, rotate, mode, position: one generated Lua file, then a reload ----
hypr "$binary" display scale DP-2 1.5 >/dev/null; monhas 'output = "DP-2"' && monhas 'scale = 1.5' && has 'hyprctl reload' || fail "scale: $(cat "$mon" 2>/dev/null)"
head -3 "$mon" | grep -q '^return {' || grep -q '^return {' "$mon" || fail 'the file returns a table'
hypr "$binary" display rotate DP-2 270 >/dev/null; monhas 'transform = 3' || fail 'rotate 270 is transform 3'
hypr "$binary" display rotate DP-2 0 >/dev/null; ! monhas 'transform' || fail 'rotate 0 drops the transform'
hypr "$binary" display mode DP-2 1920x1080@60 >/dev/null; monhas 'mode = "1920x1080@60"' || fail 'mode'
hypr "$binary" display position DP-2 2880x0 >/dev/null; monhas 'position = "2880x0"' || fail 'position'
hypr "$binary" display scale eDP-1 auto >/dev/null; monhas 'scale = "auto"' || fail 'scale auto'
[[ "$(code "$binary" display scale DP-2 9)" == 2 && "$(code "$binary" display rotate DP-2 45)" == 2 && "$(code "$binary" display mode DP-2 big)" == 2 && "$(code "$binary" display position DP-2 left)" == 2 ]] || fail 'bad values exit 2'
[[ "$(code "$binary" display scale HDMI-9 1)" == 4 ]] || fail 'a monitor that is not there exits 4'
jq -e '.monitors["DP-2"].position == "2880x0"' "$tmp/cfg/bxrig/display.json" >/dev/null || fail 'the choice is remembered'
hypr "$binary" display scale DP-2 2 --dry-run --json | jq -e '.dry_run and (.data.applied.desktop | test("would write"))' >/dev/null || fail 'dry run'
jq -e '.monitors["DP-2"].scale == "1.5"' "$tmp/cfg/bxrig/display.json" >/dev/null || fail 'dry run saved something'

# ---- mirror: the laptop panel to every external monitor ----
: > "$LOG"; hypr "$binary" display mirror on >/dev/null; monhas 'output = "DP-2", mode = "preferred"' && monhas 'mirror = "eDP-1"' || fail "mirror on: $(cat "$mon")"
hypr "$binary" display mirror off >/dev/null; ! monhas 'mirror =' || fail 'mirror off'

# ---- the laptop panel ----
hypr "$binary" display laptop off >/dev/null; monhas 'output = "eDP-1", disabled = true' || fail "laptop off: $(cat "$mon")"
hypr "$binary" display laptop on >/dev/null; ! monhas 'disabled' || fail 'laptop on'
jq 'del(.[1])' "$tmp/mons.json" > "$tmp/one.json"
set +e; MONS="$tmp/one.json" hypr "$binary" display laptop off >/dev/null 2>&1; c=$?; set -e; [[ $c == 4 ]] || fail "the only monitor cannot be turned off ($c)"

# ---- without Hyprland the file is written and nothing reloads ----
: > "$LOG"; run "$binary" display scale DP-2 1.25 --json | jq -e '.data.applied.desktop == "written"' >/dev/null || fail 'written without Hyprland'
! has 'hyprctl reload' || fail 'reload without Hyprland'

# ---- Plasma: kscreen-doctor, no file ----
rm -f "$mon"; : > "$LOG"
plasma "$binary" display scale DP-2 1.5 >/dev/null; has 'kscreen-doctor output.DP-2.enable output.DP-2.scale.1.5' || fail "kscreen: $(cat "$LOG")"
plasma "$binary" display rotate DP-2 90 >/dev/null; has 'output.DP-2.rotation.left' || fail 'plasma rotation'
[[ ! -e "$mon" ]] || fail 'plasma wrote a Hyprland file'

# ---- brightness ----
: > "$LOG"; run "$binary" display brightness up >/dev/null; has 'noctalia msg brightness-up' || fail 'brightness up via Noctalia'
run "$binary" display brightness set 40 >/dev/null; has 'brightnessctl set 40%' || fail 'brightness set'
[[ "$(code "$binary" display brightness set 500)" == 2 ]] || fail 'bad brightness'
mv "$tmp/bin/noctalia" "$tmp/n.off"; run "$binary" display brightness down >/dev/null; has 'brightnessctl set 5%-' || fail 'brightness falls back to brightnessctl'; mv "$tmp/n.off" "$tmp/bin/noctalia"

# ---- apply and reset ----
: > "$LOG"; hypr "$binary" display apply >/dev/null; has 'hyprctl reload' || fail 'apply'
hypr "$binary" display reset >/dev/null; jq -e '(.monitors | length) == 0' "$tmp/cfg/bxrig/display.json" >/dev/null && ! monhas 'output' || fail 'reset'
hypr "$binary" keys render hyprland 2>/dev/null | grep -q 'theme/monitors.lua' || run "$binary" keys render hyprland | grep -q 'theme/monitors.lua' || fail 'bxrig.lua loads monitors.lua'
echo "display-test: ok"

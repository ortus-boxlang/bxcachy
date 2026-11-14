#!/usr/bin/env bash
# `bxrig keys set|reset|conflicts`: validation, conflicts, overrides reaching the rendered Hyprland and Plasma text. Usage: keys-editor-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/home" "$tmp/cfg/hypr"
run() { env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_STATE_HOME="$tmp/state" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
k() { run "$binary" keys "$@"; }

# validation
[[ "$(code "$binary" keys set nope Super+Alt+A --yes)" == 4 ]] || fail 'an unknown binding exits 4'
[[ "$(code "$binary" keys set copy Super+Alt+A --yes)" == 4 ]] || fail 'a remap cannot be changed'
[[ "$(code "$binary" keys set ai-shell Super --yes)" == 4 ]] || fail 'a combo needs a key'
[[ "$(code "$binary" keys set ai-shell Hyper+A --yes)" == 4 ]] || fail 'an unknown modifier'
[[ "$(code "$binary" keys set ai-shell Super+Alt+Banana --yes)" == 4 ]] || fail 'an unknown key'
# a combo another BxRig binding already uses is refused, even with --force
[[ "$(code "$binary" keys set ai-shell 'Alt+Super+Space' --yes --force)" == 4 ]] || fail 'a clash with the control center (case and order do not matter)'
{ k set ai-shell Super+Alt+A || true; } | grep -q 'Nothing was changed' || fail 'plan text'
[[ "$(code "$binary" keys set ai-shell Super+Alt+A)" == 2 ]] || fail 'no --yes exits 2'
[[ ! -e "$tmp/cfg/bxrig/shortcuts.json" ]] || fail 'the plan wrote the override'

# set: the override is saved and reaches both targets
k set ai-shell Super+Alt+A --yes | grep -q 'now Super+Alt+A' || fail 'set --yes'
[[ "$(jq -r '."ai-shell"' "$tmp/cfg/bxrig/shortcuts.json")" == 'Super+Alt+A' ]] || fail 'override saved'
k render hyprland | grep -q 'hl.bind(mainMod .. " + ALT + A", hl.dsp.exec_cmd(\[\[sh -c .PATH="$HOME/.local/bin:$PATH"; bxrig ai shell' || fail "hyprland uses the new keys: $(k render hyprland | grep 'ai shell')"
! k render hyprland | grep -q '" + grave"' || fail 'the old binding is gone'
k show --json | jq -e '(.data.shortcuts[] | select(.id=="ai-shell") | .keys == "Super+Alt+A" and .custom == true) and (.data.shortcuts[] | select(.id=="logout") | .custom == false)' >/dev/null || fail 'show marks custom keys'
# a Plasma-visible binding follows too (logout is in the kglobalshortcutsrc text)
k set logout Ctrl+Alt+Q --yes >/dev/null
k render plasma | grep -q '^Log Out=Ctrl+Alt+Q,Ctrl+Alt+Del,Log Out$' || fail "plasma text follows: $(k render plasma)"
k render hyprland | grep -q 'hl.bind(mainMod .. "\|hl.bind("CTRL + ALT + Q", hl.dsp.exec_cmd("uwsm stop"))' || fail 'logout without Super'

# reset
[[ "$(code "$binary" keys reset copy --yes)" == 4 ]] || fail 'reset without an override exits 4'
[[ "$(code "$binary" keys reset ai-shell)" == 2 ]] || fail 'reset without --yes exits 2'
k reset ai-shell --yes | grep -q 'back to its default keys' || fail 'reset --yes'
k render hyprland | grep -q 'hl.bind(mainMod .. " + grave"' || fail 'default restored'
k reset logout --yes >/dev/null

# conflicts with YOUR lines: refused unless --force; `conflicts` lists them
cat > "$tmp/cfg/hypr/hyprland.lua" <<'LUA'
local mainMod = "SUPER"
hl.bind(mainMod .. " + SHIFT + Y", hl.dsp.window.fullscreen())
hl.bind("SUPER + ALT + K", function() end)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
LUA
[[ "$(code "$binary" keys set control-center Super+Shift+Y --yes)" == 4 ]] || fail 'a clash with your hyprland.lua is refused'
{ k set control-center Super+Shift+Y --yes 2>&1 || true; } | grep -q 'hyprland.lua line 2' || fail 'the message names your file and line'
[[ "$(code "$binary" keys set control-center Super+Shift+Y --yes --force)" == 0 ]] || fail '--force allows a clash with your own line'
k conflicts --json | jq -e '.data.ok == false and (.data.user | length) == 1 and .data.user[0].id == "control-center" and .data.user[0].line == 2' >/dev/null || fail "conflicts: $(k conflicts --json)"
k reset control-center --yes >/dev/null
k conflicts | grep -q 'No conflicts' || fail 'clean table and no clash'
# two bindings can end up sharing a combo only by editing the file by hand: the scan still reports it
echo '{"ai-shell":"Super+Alt+K","control-center":"super+alt+k"}' > "$tmp/cfg/bxrig/shortcuts.json"
k conflicts --json | jq -e '.data.within | length == 1' >/dev/null || fail 'duplicates inside the table are reported'
echo "keys-editor-test: ok"

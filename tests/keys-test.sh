#!/usr/bin/env bash
# `bxrig keys show|render`: pure output, no files written. Usage: keys-test.sh [binary]
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
fail() { echo "FAIL: $*" >&2; exit 1; }
out="$("$binary" keys show)"
[[ "$out" == *"Super+C"* && "$out" == *"Super+Shift+Q"* ]] || fail 'show lists the shortcuts'
"$binary" keys show --json | jq -e '.command == "keys show" and .ok and (.data.shortcuts | length) == 38' >/dev/null || fail 'show --json envelope'
"$binary" keys render xremap | grep -q 'Super-c: Ctrl-Shift-c' || fail 'xremap terminal rule'
"$binary" keys render hyprland | grep -q 'uwsm stop' || fail 'hyprland logout bind'
"$binary" keys render plasma | grep -q 'Log Out=Meta+Shift+Q' || fail 'plasma logout shortcut'
"$binary" keys render xremap --json | jq -e '.data.target == "xremap"' >/dev/null || fail 'render --json'
set +e; "$binary" keys render bogus >/dev/null 2>&1; c=$?; "$binary" keys >/dev/null 2>&1; d=$?; set -e
[[ "$c" == 2 && "$d" == 2 ]] || fail "bad usage exits 2 (got $c, $d)"
echo "keys tests passed"

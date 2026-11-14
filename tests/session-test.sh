#!/usr/bin/env bash
# `bxrig session show|set` with fake session directories, SDDM state file, sudo and id. Usage: session-test.sh [binary]
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/sessions" "$tmp/home"
printf '[Desktop Entry]\nName=Hyprland (uwsm-managed)\nExec=uwsm start hyprland.desktop\n' > "$tmp/sessions/hyprland-uwsm.desktop"
printf '[Desktop Entry]\nName=Hyprland\nExec=Hyprland\n' > "$tmp/sessions/hyprland.desktop"
printf '[Desktop Entry]\nName=Plasma (Wayland)\nExec=startplasma-wayland\n' > "$tmp/sessions/plasma.desktop"
printf '[Last]\nSession=%s/plasma.desktop\nUser=dev\n' "$tmp/sessions" > "$tmp/state.conf"
printf '#!/usr/bin/env bash\n[[ "$1" == --version ]] && { echo "Sudo version 1.9"; exit 0; }\n"$@"\n' > "$tmp/bin/sudo"
printf '#!/usr/bin/env bash\nif [[ "$1" == -u ]]; then echo "${MOCK_UID:-1000}"; else /usr/bin/id "$@"; fi\n' > "$tmp/bin/id"
chmod +x "$tmp/bin/"*
run() { env HOME="$tmp/home" PATH="$tmp/bin:$PATH" BXRIG_SESSION_DIRS="$tmp/sessions" BXRIG_SDDM_STATE="$tmp/state.conf" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

run "$binary" session show | grep -q 'plasma.desktop  Plasma (Wayland)  (preselected)' || fail 'show marks the preselected session'
run "$binary" session show --json | jq -e '(.data.sessions | length) == 3 and (.data.preselected | endswith("plasma.desktop"))' >/dev/null || fail 'show --json'
[[ "$(code "$binary" session set hyprland)" == 2 ]] || fail 'set without --yes exits 2'
grep -q plasma.desktop "$tmp/state.conf" || fail 'a plan changed the state file'
[[ "$(code "$binary" session set hyprland --dry-run)" == 0 ]] || fail 'dry run exits 0'
grep -q plasma.desktop "$tmp/state.conf" || fail 'a dry run changed the state file'
[[ "$(MOCK_UID=0 code "$binary" session set hyprland --yes)" == 4 ]] || fail 'root exits 4'
[[ "$(code "$binary" session set gnome --yes)" == 4 ]] || fail 'unknown target exits 4'
[[ "$(code "$binary" session set hyprland --yes)" == 0 ]] || fail 'set hyprland --yes exits 0'
grep -qx "Session=$tmp/sessions/hyprland-uwsm.desktop" "$tmp/state.conf" || fail 'state file now preselects hyprland (uwsm)'
grep -qx 'User=dev' "$tmp/state.conf" || fail 'the other state lines were kept'
[[ "$(grep -c '^\[Last\]$' "$tmp/state.conf")" == 1 ]] || fail '[Last] appears once'
[[ -f "$tmp/state.conf.bxrig.bak" ]] && grep -q plasma.desktop "$tmp/state.conf.bxrig.bak" || fail 'a backup of the old state file was kept'
[[ "$(code "$binary" session set plasma --yes)" == 0 ]] || fail 'set plasma --yes exits 0'
grep -qx "Session=$tmp/sessions/plasma.desktop" "$tmp/state.conf" || fail 'state file preselects plasma again'
run "$binary" session set hyprland --yes --json | jq -e '.ok and (.data.done | map(.id) == ["backup","write"])' >/dev/null || fail 'set --json is one envelope'
[[ "$(code "$binary" session)" == 2 ]] || fail 'bare session exits 2'
echo "session tests passed"

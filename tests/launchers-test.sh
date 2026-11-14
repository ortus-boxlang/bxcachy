#!/usr/bin/env bash
# `bxrig launchers on|off|status`: one .desktop per Control Center page, opt-in, never over your edits. Fake terminal and a fake id. Usage: launchers-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/cfg"
printf '#!/usr/bin/env bash\nif [[ "$1" == -u ]]; then echo "${MOCK_UID:-1000}"; else /usr/bin/id "$@"; fi\n' > "$tmp/bin/id"; chmod +x "$tmp/bin/id"
for t in ghostty kitty; do printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/bin/$t"; chmod +x "$tmp/bin/$t"; done
run() { env HOME="$tmp/home" XDG_DATA_HOME="$tmp/data" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_STATE_HOME="$tmp/state" BXRIG_SELF=/opt/bxrig/bxrig PATH="$tmp/bin:$PATH" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
apps="$tmp/data/applications"; icon="$tmp/data/icons/hicolor/256x256/apps/bxrig.png"

# nothing exists until you ask
run "$binary" launchers status --json | jq -e '.data.enabled == false and .data.present == 0 and .data.total == 17' >/dev/null || fail 'status before'
[[ "$(code "$binary" launchers on)" == 2 ]] || fail 'on without --yes is a plan (exit 2)'
[[ "$(code "$binary" launchers on --dry-run)" == 0 ]] || fail 'dry run exits 0'
[[ ! -e "$apps" && ! -e "$icon" ]] || fail 'a plan or dry run wrote files'
[[ "$(code "$binary" launchers)" == 0 ]] || fail 'bare launchers is status'
[[ "$(code "$binary" launchers nope)" == 2 ]] || fail 'unknown subcommand exits 2'
[[ "$(MOCK_UID=0 code "$binary" launchers on --yes)" == 4 ]] || fail 'root exits 4'

# on: the first terminal in xdg-terminals.list, one entry per page, the icon
printf 'com.mitchellh.ghostty.desktop\n' > "$tmp/cfg/xdg-terminals.list"
run "$binary" launchers on --dry-run | grep -q "write $apps/bxrig-tui-databases.desktop" || fail 'plan names the files'
[[ "$(code "$binary" launchers on --yes)" == 0 ]] || fail 'on --yes exits 0'
[[ "$(ls "$apps"/bxrig-tui-*.desktop | wc -l)" == 17 ]] || fail 'one entry per page'
f="$apps/bxrig-tui-databases.desktop"
grep -qx 'Name=BxRig Databases' "$f" || fail "name: $(cat "$f")"
grep -qx 'Icon=bxrig' "$f" || fail 'icon name'
grep -qx 'Categories=Development;System;' "$f" || fail 'categories'
grep -qx 'Exec=ghostty -e /opt/bxrig/bxrig tui databases' "$f" || fail "exec: $(grep '^Exec' "$f")"
! grep -q StartupWMClass "$f" || fail 'no StartupWMClass is written'
[[ "$(stat -c %a "$f")" == 644 ]] || fail 'mode 644'
cmp "$icon" "$root/assets/icon.png" || fail 'the icon is the embedded one'
run "$binary" launchers status --json | jq -e '.data.enabled and .data.present == 17 and .data.icon and .data.terminal == "ghostty"' >/dev/null || fail 'status after'
run "$binary" launchers status | grep -q '17 of 17 launchers' || fail 'status text'

# again: nothing to do
[[ "$(code "$binary" launchers on --yes)" == 0 ]] || fail 'on twice is fine'

# an entry you edited is kept (on and off), and a changed icon is kept
echo '# mine' >> "$f"
run "$binary" launchers on --yes | grep -q 'Kept 1 you edited' || fail 'on keeps an edited entry'
grep -q '# mine' "$f" || fail 'on overwrote an edited entry'
echo mine > "$icon"
run "$binary" launchers off --dry-run | grep -q "keep   $f" || fail 'off plan keeps the edited entry'
[[ "$(code "$binary" launchers off)" == 2 ]] || fail 'off without --yes exits 2'
[[ "$(code "$binary" launchers off --yes)" == 0 ]] || fail 'off --yes exits 0'
[[ "$(ls "$apps"/bxrig-tui-*.desktop | wc -l)" == 1 && -f "$f" ]] || fail 'off removed only the unedited entries'
grep -qx mine "$icon" || fail 'off removed an icon you changed'
rm "$f"

# the icon goes while it is still BxRig's; `remove launchers` is the same as `launchers off`
rm "$icon"
[[ "$(code "$binary" launchers on --yes)" == 0 ]] || fail 'on again'
cmp "$icon" "$root/assets/icon.png" || fail 'the icon is written again when it is missing'
[[ "$(code "$binary" remove launchers)" == 2 ]] || fail 'remove launchers without --yes is a plan'
[[ "$(ls "$apps"/bxrig-tui-*.desktop | wc -l)" == 17 ]] || fail 'the plan removed files'
[[ "$(code "$binary" remove launchers --yes)" == 0 ]] || fail 'remove launchers --yes'
[[ -z "$(ls "$apps"/bxrig-tui-*.desktop 2>/dev/null)" && ! -e "$icon" ]] || fail 'remove launchers left files behind'
run "$binary" launchers off --yes | grep -q 'No launchers' || fail 'off with nothing there says so'
run "$binary" launchers status --json | jq -e '.data.enabled == false' >/dev/null || fail 'status after off'

# another terminal: kitty takes its command without -e
printf 'kitty.desktop\n' > "$tmp/cfg/xdg-terminals.list"
[[ "$(code "$binary" launchers on --yes)" == 0 ]] || fail 'on with kitty'
grep -qx 'Exec=kitty /opt/bxrig/bxrig tui logs' "$apps/bxrig-tui-logs.desktop" || fail "kitty exec: $(grep '^Exec' "$apps/bxrig-tui-logs.desktop")"
# the terminal changed: the entries are BxRig's still (journal), so they update
printf 'com.mitchellh.ghostty.desktop\n' > "$tmp/cfg/xdg-terminals.list"
[[ "$(code "$binary" launchers off --yes)" == 0 ]] || fail 'off after the terminal changed'
[[ -z "$(ls "$apps"/bxrig-tui-*.desktop 2>/dev/null)" ]] || fail 'off left entries after the terminal changed'

# no terminal at all: exit 4
rm "$tmp/bin/ghostty" "$tmp/bin/kitty"; rm -f "$tmp/cfg/xdg-terminals.list"
mkdir -p "$tmp/nobin"; for c in sh cat id base64 rm sed grep; do ln -sf "$(command -v "$c")" "$tmp/nobin/$c"; done
set +e; env HOME="$tmp/home" XDG_DATA_HOME="$tmp/data" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_STATE_HOME="$tmp/state" PATH="$tmp/nobin" "$binary" launchers on --yes >/dev/null 2>&1; rc=$?; set -e
[[ "$rc" == 4 ]] || fail "no terminal exits 4 (got $rc)"
echo "launchers-test: ok"

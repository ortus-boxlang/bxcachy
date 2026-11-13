#!/usr/bin/env bash
# `bxcachy update ...` and `system update` with a fake curl serving local files and fake systemctl, notify-send, snapper, pacman. Usage: update-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/srv/stable" "$tmp/srv/beta" "$tmp/inst"; export LOG="$tmp/log"; : > "$LOG"
# the fake server: http://fake/<path> is $tmp/srv/<path>; curl -o FILE URL copies, otherwise prints
printf '#!/usr/bin/env bash\nout=""; url=""\nwhile [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift ;; http://*) url="$1" ;; esac; shift; done\nsrc="%s/srv/${url#http://fake/}"\n[ -f "$src" ] || exit 22\nif [ -n "$out" ]; then cp "$src" "$out"; else cat "$src"; fi\n' "$tmp" > "$tmp/bin/curl"
for t in systemctl notify-send snapper yay; do printf '#!/usr/bin/env bash\necho "%s $*" >> "$LOG"\n' $t > "$tmp/bin/$t"; done
printf '#!/usr/bin/env bash\necho "sudo $*" >> "$LOG"\n' > "$tmp/bin/sudo"
printf '#!/usr/bin/env bash\nprintf "pkg1 1 -> 2\\npkg2 1 -> 2\\n"\n' > "$tmp/bin/checkupdates"
chmod +x "$tmp/bin"/*
echo "old build" > "$tmp/inst/bxcachy"; chmod +x "$tmp/inst/bxcachy"
new="$tmp/srv/beta/bxcachy-linux-x86_64"; echo "new build" > "$new"; sum="$(sha256sum "$new" | cut -d' ' -f1)"
echo "$sum  bxcachy-linux-x86_64" > "$new.sha256"
printf 'version=0.12.0\ncommit=abc1234\nsha256=%s\nbuiltAt=2026-11-13T00:00:00Z\n' "$sum" > "$tmp/srv/beta/version-latest.properties"
oldsum="$(sha256sum "$tmp/inst/bxcachy" | cut -d' ' -f1)"
printf 'version=0.11.0\ncommit=1111111\nsha256=%s\nbuiltAt=2026-11-01T00:00:00Z\n' "$oldsum" > "$tmp/srv/stable/version-latest.properties"
run() { env HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_BASE_URL=http://fake BXCACHY_SELF="$tmp/inst/bxcachy" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

# channels
run "$binary" update channel | grep -q 'channel: stable' || fail 'default channel is stable'
[[ "$(code "$binary" update channel nightly)" == 4 ]] || fail 'unknown channel exits 4'
# stable: the binary matches the published sha, so it is current (and two system updates are counted)
run "$binary" update check --json | jq -e '.data.update_available == false and .data.system_updates == 2 and .data.channel == "stable"' >/dev/null || fail "stable check: $(run "$binary" update check --json)"
# beta: a different sha is an update (exit 10)
run "$binary" update channel beta >/dev/null
[[ "$(code "$binary" update check)" == 10 ]] || fail 'beta update available exits 10'
run "$binary" update check --notify >/dev/null || true; grep -q '^notify-send -a BxCachy BxCachy updates' "$LOG" || fail "notification: $(cat "$LOG")"
# apply: plan, then replace; the checksum must match
[[ "$(code "$binary" update apply)" == 2 ]] || fail 'apply without --yes exits 2'
echo "deadbeef  bxcachy-linux-x86_64" > "$new.sha256"
[[ "$(code "$binary" update apply --yes)" == 5 ]] || fail 'a checksum mismatch exits 5'
grep -q 'old build' "$tmp/inst/bxcachy" || fail 'the binary changed despite the mismatch'
echo "$sum  bxcachy-linux-x86_64" > "$new.sha256"
run "$binary" update apply --yes | grep -q 'Updated' || fail 'apply'
grep -q 'new build' "$tmp/inst/bxcachy" && [[ -x "$tmp/inst/bxcachy" ]] || fail 'the binary was replaced and is executable'
run "$binary" update apply --yes | grep -q 'Already on the latest' || fail 'already current'
[[ "$(code "$binary" update check)" == 0 ]] || fail 'current after the update'
# notifications: a daily user timer
: > "$LOG"; run "$binary" update notifications on >/dev/null
grep -q 'OnCalendar=daily' "$tmp/cfg/systemd/user/bxcachy-update-check.timer" && grep -q 'bxcachy update check --notify' "$tmp/cfg/systemd/user/bxcachy-update-check.service" || fail 'timer units'
grep -q 'systemctl --user enable --now bxcachy-update-check.timer' "$LOG" || fail 'timer enabled'
run "$binary" update notifications status | grep -q 'on (daily)' || fail 'status on'
run "$binary" update notifications off >/dev/null; grep -q 'disable --now bxcachy-update-check.timer' "$LOG" || fail 'timer disabled'
# the server is down: exit 5
rm -rf "$tmp/srv/beta"; [[ "$(code "$binary" update check)" == 5 ]] || fail 'unreachable server exits 5'
# system update: a snapshot first when snapper is there
[[ "$(code "$binary" system update)" == 2 ]] || fail 'system update without --yes exits 2'
: > "$LOG"; run "$binary" system update --yes >/dev/null
[[ "$(sed -n 1p "$LOG")" == sudo\ snapper* ]] && grep -q 'sudo pacman -Syu --noconfirm' "$LOG" && grep -q 'yay -Sua --noconfirm' "$LOG" || fail "system update order: $(cat "$LOG")"
echo "update-test ok"

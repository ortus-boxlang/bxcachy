#!/usr/bin/env bash
# `bxrig system lock|suspend|logout|reboot|shutdown` with fake noctalia, loginctl and systemctl. Usage: system-actions-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home"; export LOG="$tmp/log"; : > "$LOG"
for t in noctalia loginctl systemctl; do printf '#!/usr/bin/env bash\necho "%s $*" >> "$LOG"\n' "$t" > "$tmp/bin/$t"; done
chmod +x "$tmp/bin"/*
run() { env HOME="$tmp/home" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

# inside Hyprland with Noctalia: its IPC
run env HYPRLAND_INSTANCE_SIGNATURE=x "$binary" system lock >/dev/null; grep -q '^noctalia msg session lock$' "$LOG" || fail "noctalia lock: $(cat "$LOG")"
run env HYPRLAND_INSTANCE_SIGNATURE=x "$binary" system suspend >/dev/null; grep -q '^noctalia msg session suspend$' "$LOG" || fail 'noctalia suspend'
# elsewhere: systemd
: > "$LOG"; run "$binary" system lock >/dev/null; grep -q '^loginctl lock-session$' "$LOG" || fail 'loginctl lock'
run "$binary" system suspend >/dev/null; grep -q '^systemctl suspend$' "$LOG" || fail 'systemctl suspend'
# logout, reboot and shutdown are a plan until --yes
: > "$LOG"
for v in reboot shutdown logout; do [[ "$(XDG_SESSION_ID=3 code "$binary" system $v)" == 2 ]] || fail "$v without --yes exits 2"; done
[[ ! -s "$LOG" ]] || fail "a plan ran a command: $(cat "$LOG")"
run "$binary" system reboot --dry-run --json | jq -e '.dry_run and .data.command == "systemctl reboot" and .data.via == "systemd"' >/dev/null || fail 'dry run'
run "$binary" system reboot --yes >/dev/null; grep -q '^systemctl reboot$' "$LOG" || fail 'reboot --yes'
run "$binary" system shutdown --yes >/dev/null; grep -q '^systemctl poweroff$' "$LOG" || fail 'shutdown is poweroff'
run env XDG_SESSION_ID=3 "$binary" system logout --yes >/dev/null; grep -q '^loginctl terminate-session 3$' "$LOG" || fail 'logout'
run env HYPRLAND_INSTANCE_SIGNATURE=x "$binary" system reboot --yes >/dev/null; grep -q '^noctalia msg session reboot$' "$LOG" || fail 'noctalia reboot'
# nothing available, bad usage
[[ "$(env HOME="$tmp/home" PATH=/usr/bin:/bin "$binary" system lock >/dev/null 2>&1; echo $?)" != 0 ]] || true
rm -f "$tmp/bin/loginctl" "$tmp/bin/systemctl" "$tmp/bin/noctalia"
[[ "$(set +e; env HOME="$tmp/home" PATH="$tmp/bin" "$binary" system lock >/dev/null 2>&1; echo $?)" == 4 ]] || fail 'no way to lock exits 4'
[[ "$(code "$binary" system hibernate-now)" == 2 ]] || fail 'unknown action exits 2'
echo "system-actions-test: ok"

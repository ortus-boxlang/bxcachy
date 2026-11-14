#!/usr/bin/env bash
# `bxrig screenshot|qr|notify|keys sheet` with fake tools. Usage: capture-notify-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/nobin"; export LOG="$tmp/log"; : > "$LOG"
logger() { printf '#!/usr/bin/env bash\necho "%s $*" >> "$LOG"\n%s\n' "$1" "${2:-}" > "$tmp/bin/$1"; }
logger noctalia 'case "$2" in notification-dnd-status) echo "on" ;; esac'
for t in spectacle grim slurp systemd-run systemctl wl-copy; do logger $t; done
logger tesseract 'echo "some text"'
logger zbarimg 'echo "https://example.com"'
logger qrencode 'echo "QR"'
chmod +x "$tmp/bin"/*
run() { env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

# screenshots: Noctalia on Hyprland, Spectacle on Plasma, grim and slurp without Noctalia
run "$binary" screenshot screen | true; grep -q 'noctalia msg screenshot-fullscreen' "$LOG" || fail "screen: $(cat "$LOG")"
run "$binary" screenshot region --edit; grep -q 'noctalia msg screenshot-region --annotate' "$LOG" || fail 'region --edit'
run "$binary" screenshot window; grep -q 'noctalia msg screenshot-window' "$LOG" || fail 'window'
: > "$LOG"; BXRIG_DESKTOP=KDE run "$binary" screenshot region; grep -q 'spectacle -r' "$LOG" || fail 'plasma uses spectacle'
mv "$tmp/bin/noctalia" "$tmp/noctalia.off"; : > "$LOG"
run "$binary" screenshot region --dry-run | grep -q 'grim -g' || fail 'fallback is grim and slurp'
mv "$tmp/noctalia.off" "$tmp/bin/noctalia"
[[ "$(code "$binary" screenshot nope)" == 2 ]] || fail 'unknown mode exits 2'

# OCR and QR: a region into a temp file, then the text or the code goes to the clipboard
: > "$LOG"; run "$binary" screenshot ocr | grep -q 'Copied' || fail 'ocr'
grep -q '^grim -g' "$LOG" && grep -q '^tesseract ' "$LOG" && grep -q '^wl-copy' "$LOG" || fail "ocr tools: $(cat "$LOG")"
: > "$LOG"; run "$binary" screenshot qr | grep -q 'Copied' || fail 'qr scan'; grep -q '^zbarimg -q --raw' "$LOG" || fail 'zbarimg'
: > "$LOG"; BXRIG_DESKTOP=KDE run "$binary" screenshot ocr --dry-run | grep -q 'spectacle -b -n -r -o' || fail 'plasma ocr uses spectacle'
rc=0; env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" PATH="$tmp/nobin" "$binary" screenshot ocr >/dev/null 2>&1 || rc=$?; [[ "$rc" == 4 ]] || fail "ocr without tools exits 4 (got $rc)"

# qr make
run "$binary" qr "hello" | grep -q 'QR' || fail 'qr make'; grep -q 'qrencode -t ANSIUTF8 hello' "$LOG" || fail 'qr argv'
run "$binary" qr hello --out="$tmp/h.png" >/dev/null; grep -q "qrencode -o $tmp/h.png hello" "$LOG" || fail 'qr --out'

# notify
: > "$LOG"; run "$binary" notify dnd on >/dev/null; grep -q 'noctalia msg notification-dnd-set on' "$LOG" || fail 'dnd on'
run "$binary" notify dnd toggle >/dev/null; grep -q 'notification-dnd-toggle' "$LOG" || fail 'dnd toggle'
run "$binary" notify dnd status | grep -q 'Do Not Disturb: on' || fail 'dnd status'
: > "$LOG"; run "$binary" notify snooze 2h | grep -q '7200 seconds' || fail 'snooze 2h'
grep -q 'systemctl --user stop bxrig-snooze.timer' "$LOG" && grep -q 'notification-dnd-set on' "$LOG" && grep -q 'systemd-run --user --quiet --unit=bxrig-snooze --on-active=7200s noctalia msg notification-dnd-set off' "$LOG" || fail "snooze: $(cat "$LOG")"
run "$binary" notify snooze | grep -q '1800 seconds' || fail 'snooze default is 30 minutes'
run "$binary" notify snooze 90s | grep -q '90 seconds' || fail 'snooze 90s'
: > "$LOG"; run "$binary" notify snooze off >/dev/null; grep -q 'systemctl --user stop bxrig-snooze.timer' "$LOG" && grep -q 'notification-dnd-set off' "$LOG" || fail 'snooze off'
[[ "$(code "$binary" notify snooze soon)" == 4 ]] || fail 'a bad duration exits 4'
: > "$LOG"; run "$binary" notify clear >/dev/null; grep -q 'notification-clear-active' "$LOG" && ! grep -q 'clear-history' "$LOG" || fail 'clear'
run "$binary" notify clear --history >/dev/null; grep -q 'notification-clear-history' "$LOG" || fail 'clear --history'
rc=0; env HOME="$tmp/home" PATH="$tmp/nobin" "$binary" notify dnd on >/dev/null 2>&1 || rc=$?; [[ "$rc" == 4 ]] || fail "no noctalia exits 4 (got $rc)"
[[ "$(code "$binary" notify)" == 2 ]] || fail 'usage exits 2'

# keys sheet: the same rows as `keys show`, and the new shortcuts are in it
run "$binary" keys sheet --json | jq -e '(.data.lines | length) == 38 and (.data.lines | map(select(startswith("Super+K "))) | length) == 1' >/dev/null || fail 'keys sheet json'
run "$binary" keys sheet | grep -q 'Super+Shift+4   Screenshot: a region' || fail 'keys sheet text'
run "$binary" keys render hyprland | grep -q 'screenshot region' || fail 'Hyprland module binds the screenshot keys'
echo "capture-notify-test ok"

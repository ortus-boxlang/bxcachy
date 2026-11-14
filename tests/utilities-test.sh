#!/usr/bin/env bash
# `bxrig clipboard` and `bxrig record` with fake cliphist, wl-copy, wf-recorder, slurp, pgrep, pkill and Rofi. Usage: utilities-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/fake" "$tmp/videos"; export LOG="$tmp/log" FAKE="$tmp/fake"; : > "$LOG"
cat > "$tmp/bin/cliphist" <<'SH'
#!/usr/bin/env bash
case "$1" in
  list) printf '3\tthird entry\n2\tsecond entry\n1\tfirst entry\n' ;;
  decode) read -r line; echo "decoded:${line#*$'\t'}" ;;
  wipe) echo "cliphist wipe" >> "$LOG" ;;
esac
SH
printf '#!/usr/bin/env bash\ncat > "$FAKE/clipboard"\n' > "$tmp/bin/wl-copy"
printf '#!/usr/bin/env bash\ncat > /dev/null\nn=$(( $(cat "$FAKE/n" 2>/dev/null || echo 0) + 1 )); echo $n > "$FAKE/n"\nsed -n "${n}p" "$FAKE/answers"\n' > "$tmp/bin/rofi"
printf '#!/usr/bin/env bash\necho "wf-recorder $*" >> "$LOG"; touch "$FAKE/recording"; sleep 30\n' > "$tmp/bin/wf-recorder"
printf '#!/usr/bin/env bash\necho "0,0 100x100"\n' > "$tmp/bin/slurp"
printf '#!/usr/bin/env bash\n[[ -e "$FAKE/recording" ]]\n' > "$tmp/bin/pgrep"
printf '#!/usr/bin/env bash\necho "pkill $*" >> "$LOG"; rm -f "$FAKE/recording"\n' > "$tmp/bin/pkill"
chmod +x "$tmp/bin"/*
run() { env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_VIDEOS="$tmp/videos" FAKE="$FAKE" LOG="$LOG" PATH="$tmp/bin:$PATH" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

# ---- clipboard ----
run "$binary" clipboard status --json | jq -e '.data.cliphist and .data.wl_clipboard and .data.entries == 3' >/dev/null || fail 'status'
run "$binary" runner menu-set rofi >/dev/null
printf '1\n' > "$FAKE/answers"
run "$binary" clipboard pick | grep -q 'Copied' || fail 'pick'
[[ "$(cat "$FAKE/clipboard")" == 'decoded:second entry' ]] || fail "the chosen entry reaches the clipboard: $(cat "$FAKE/clipboard")"
rm -f "$FAKE/n" "$FAKE/clipboard"; : > "$FAKE/answers"
run "$binary" clipboard pick | grep -q 'Cancelled' || fail 'cancel'
[[ ! -e "$FAKE/clipboard" ]] || fail 'a cancelled pick copied something'
[[ "$(code "$binary" clipboard clear)" == 2 ]] || fail 'clear without --yes exits 2'
[[ ! -s "$LOG" ]] || fail 'the clear plan wiped the history'
run "$binary" clipboard clear --yes | grep -q 'wiped' || fail 'clear --yes'
grep -q 'cliphist wipe' "$LOG" || fail 'wipe ran'
mkdir -p "$tmp/nobin"; ln -sf "$(command -v sh)" "$tmp/nobin/sh"
set +e; env HOME="$tmp/home" PATH="$tmp/nobin" "$binary" clipboard pick >/dev/null 2>&1; rc=$?; set -e; [[ "$rc" == 4 ]] || fail "missing tools exit 4 (got $rc)"

# ---- record ----
: > "$LOG"; rm -f "$FAKE/recording"
run "$binary" record status --json | jq -e '.data.recording == false' >/dev/null || fail 'status: not recording'
run "$binary" record --dry-run --json | jq -e '.data.region == false and (.data.file | test("/videos/bxrig-[0-9]{8}-[0-9]{6}[.]mp4$"))' >/dev/null || fail 'dry-run toggle starts when idle'
[[ ! -e "$FAKE/recording" ]] || fail 'dry-run recorded'
run "$binary" record | grep -q 'Recording to' || fail 'toggle starts'
for _ in $(seq 1 20); do [[ -e "$FAKE/recording" ]] && break; sleep 0.2; done
grep -q '^wf-recorder -f .*/videos/bxrig-.*[.]mp4$' "$LOG" || fail "wf-recorder args: $(cat "$LOG")"
run "$binary" record status --json | jq -e '.data.recording == true' >/dev/null || fail 'status: recording'
run "$binary" record start | grep -q 'already running' || fail 'a second start is refused politely'
run "$binary" record | grep -q 'stopped and saved' || fail 'toggle stops'
grep -q 'pkill -INT -x wf-recorder' "$LOG" || fail 'stopped with SIGINT'
run "$binary" record stop | grep -q 'Nothing is recording' || fail 'stop when idle'
run "$binary" record start --region --dry-run --json | jq -e '.data.region == true and (.data.command[2] | contains("slurp"))' >/dev/null || fail 'region uses slurp'
rm "$tmp/bin/wf-recorder"; [[ "$(code "$binary" record start)" == 4 ]] || fail 'no wf-recorder exits 4'
echo "utilities-test: ok"

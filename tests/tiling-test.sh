#!/usr/bin/env bash
# `bxcachy tiling on|off|status` with fake kreadconfig6, kwriteconfig6 and qdbus6. Usage: tiling-test.sh [binary]
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/state"
export LOG="$tmp/log" STATE="$tmp/state"
# kwinrc is one file per key; qdbus6 knows KWin only while $STATE/kwin exists
cat > "$tmp/bin/kreadconfig6" <<'MOCK'
#!/usr/bin/env bash
[[ -f "$STATE/${@: -1}" ]] && cat "$STATE/${@: -1}" || true
MOCK
cat > "$tmp/bin/kwriteconfig6" <<'MOCK'
#!/usr/bin/env bash
printf '%s' "${@: -1}" > "$STATE/${@: -2:1}"; echo "kwriteconfig6 $*" >> "$LOG"
MOCK
cat > "$tmp/bin/qdbus6" <<'MOCK'
#!/usr/bin/env bash
[[ -f "$STATE/kwin" ]] || exit 1
echo "qdbus6 $*" >> "$LOG"
if [[ "$*" == *isScriptLoaded* ]]; then [[ "$(cat "$STATE/hyprkwinEnabled" 2>/dev/null)" == true && ! -f "$STATE/unloaded" ]] && echo true || echo false; fi
if [[ "$*" == *unloadScript* ]]; then touch "$STATE/unloaded"; fi
if [[ "$*" == *reconfigure* ]]; then rm -f "$STATE/unloaded"; fi
exit 0
MOCK
printf '#!/usr/bin/env bash\nif [[ "$1" == -u ]]; then echo "${MOCK_UID:-1000}"; else /usr/bin/id "$@"; fi\n' > "$tmp/bin/id"
chmod +x "$tmp/bin/"*
run() { env HOME="$tmp/home" PATH="$tmp/bin:$PATH" LOG="$LOG" STATE="$STATE" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

# not installed
[[ "$(code "$binary" tiling status)" == 4 ]] || fail 'status without HyprKwin exits 4'
[[ "$(code "$binary" tiling on)" == 4 ]] || fail 'on without HyprKwin exits 4'
mkdir -p "$tmp/home/.local/share/hyprkwin"
[[ "$(MOCK_UID=0 code "$binary" tiling on)" == 4 ]] || fail 'root exits 4'
[[ ! -s "$LOG" ]] || fail 'a refused run changed something'

# KWin running: on, status, off act at once
touch "$STATE/kwin"
[[ "$(code "$binary" tiling status)" == 1 ]] || fail 'status is off (1) before enabling'
run "$binary" tiling on >/dev/null || fail 'tiling on'
grep -Fq 'kwriteconfig6 --file kwinrc --group Plugins --key hyprkwinEnabled true' "$LOG" || fail 'the plugin flag is set'
grep -Fq 'org.kde.KWin.reconfigure' "$LOG" || fail 'KWin is reconfigured'
[[ "$(code "$binary" tiling status)" == 0 ]] || fail 'status is on (0)'
out="$(run "$binary" tiling status --json)"
[[ "$(jq -r '.data.enabled' <<<"$out")" == true && "$(jq -r '.data.loaded' <<<"$out")" == true && "$(jq -r '.exit' <<<"$out")" == 0 ]] || fail 'status json when on'
: > "$LOG"; run "$binary" tiling off >/dev/null || fail 'tiling off'
grep -Fq 'unloadScript hyprkwin' "$LOG" || fail 'the script is unloaded at once'
grep -Fq 'hyprkwinEnabled false' "$LOG" || fail 'the plugin flag is cleared'
[[ "$(code "$binary" tiling status)" == 1 ]] || fail 'status is off (1) after disabling'
[[ "$(run "$binary" tiling on --json | jq -r '.data.applied')" == true ]] || fail 'on json says it was applied'

# KWin not running: only the flag changes
rm "$STATE/kwin"; : > "$LOG"
out="$(run "$binary" tiling off)"; grep -Fq 'next Plasma login' <<<"$out" || fail 'the output says it takes effect at the next login'
grep -Fq qdbus6 "$LOG" && fail 'no D-Bus calls without KWin'

# layouts: `hyprkwinctl layout [NAME]` for the current workspace
printf '#!/usr/bin/env bash\necho "hyprkwinctl $*" >> "$LOG"\n[[ -z "$2" ]] && echo "dwindle"\nexit 0\n' > "$tmp/bin/hyprkwinctl"; chmod +x "$tmp/bin/hyprkwinctl"
[[ "$(code "$binary" tiling layout master)" == 4 ]] || fail 'layout without a running KWin exits 4'
touch "$STATE/kwin"; : > "$LOG"
run "$binary" tiling layout master | grep -q 'now uses the master layout' || fail 'layout NAME'
grep -q '^hyprkwinctl layout master$' "$LOG" || fail "hyprkwinctl was run: $(cat "$LOG")"
[[ "$(run "$binary" tiling layout)" == dwindle ]] || fail 'layout alone shows the current layout'
for l in dwindle master monocle scrolling stage; do [[ "$(code "$binary" tiling layout $l)" == 0 ]] || fail "layout $l is accepted"; done
[[ "$(code "$binary" tiling layout floating)" == 4 ]] || fail 'floating is not a HyprKwin layout (exit 4)'
run "$binary" tiling layout stage --json | jq -e '.data.layout == "stage" and .data.set == true' >/dev/null || fail 'layout --json'
mv "$tmp/bin/hyprkwinctl" "$tmp/hkc.off"; [[ "$(code "$binary" tiling layout master)" == 4 ]] || fail 'no hyprkwinctl exits 4'
rm -f "$STATE/kwin"

# usage
[[ "$(code "$binary" tiling)" == 2 ]] || fail 'tiling alone is a usage error'
[[ "$(code "$binary" tiling toggle)" == 2 ]] || fail 'unknown verb is a usage error'
echo 'tiling tests passed'

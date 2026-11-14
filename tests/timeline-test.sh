#!/usr/bin/env bash
# `bxrig backup timeline` and `bxrig timemachine` outside a terminal. Usage: timeline-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
H="$tmp/home"; mkdir -p "$tmp/bin" "$H/.config/hypr" "$tmp/disk"; export LOG="$tmp/log"; : > "$LOG"
echo hl > "$H/.config/hypr/hyprland.lua"
cat > "$tmp/bin/restic" <<'F'
#!/usr/bin/env bash
echo "restic $*" >> "$LOG"
case "$1" in snapshots) printf '[{"id":"aaaaaaaaaaaa1111","short_id":"aaaaaaaa","time":"2026-11-10T10:00:00.123Z","hostname":"box","paths":["/home/dev/Projects"]},{"id":"bbbbbbbbbbbb2222","short_id":"bbbbbbbb","time":"2026-11-12T10:00:00Z","hostname":"box","paths":["/home/dev/Projects"]}]\n' ;; esac
exit 0
F
printf '#!/usr/bin/env bash\ncase "$1" in -Qqe|-Qqm) echo git ;; esac\n' > "$tmp/bin/pacman"
printf '#!/usr/bin/env bash\nif [[ "$1" == -u ]]; then echo 1000; else /usr/bin/id "$@"; fi\n' > "$tmp/bin/id"
chmod +x "$tmp/bin"/*
run() { env HOME="$H" USER=dev BXRIG_CONFIG_HOME="$H/.config" BXRIG_DATA_HOME="$tmp/data" BXRIG_SELF=/usr/bin/bxrig BXRIG_NOW_EPOCH=1794736800 PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1 < /dev/null; local c=$?; set -e; echo "$c"; }

# ---- an injected timeline is passed through ----
printf '{"now":1794000000,"total":1,"rows":[{"id":"config","label":"Config","kind":"config","target":"","points":[{"id":"x","time":"2026-11-01T00:00:00","epoch":1793000000,"label":"manual","tier":"monthly","size":1}],"error":""}]}' > "$tmp/tl.json"
BXRIG_TIMELINE_FILE="$tmp/tl.json" run "$binary" backup timeline --json | jq -e '.data.total == 1 and .data.rows[0].points[0].id == "x"' >/dev/null || fail 'injected timeline'

# ---- the real thing: config snapshots and restic snapshots ----
run "$binary" backup config now --reason=first >/dev/null
run "$binary" backup data target add usb --type=local --path="$tmp/disk/repo" >/dev/null
run "$binary" backup data target add cloud --type=s3 --bucket=b --keys-file=<(printf 'AWS_ACCESS_KEY_ID=a\nAWS_SECRET_ACCESS_KEY=b\n') >/dev/null
run "$binary" backup data init usb --yes >/dev/null
run "$binary" backup timeline --json | jq -e '
  (.data.rows | map(.id)) == ["system","config","files-cloud","files-usb"] and
  (.data.rows[1].points | length == 1) and .data.rows[1].points[0].label == "first" and
  (.data.rows[3].points | map(.id)) == ["bbbbbbbb","aaaaaaaa"] and .data.rows[3].points[0].tier == "daily" and .data.rows[3].points[0].epoch == 1794477600 and
  (.data.rows[2].error == "not initialized") and .data.total == 3' >/dev/null || fail "timeline: $(run "$binary" backup timeline --json | jq -c .data.rows)"
run "$binary" backup timeline | grep -q 'Files usb   2 backups   latest:' || fail 'text summary'
run "$binary" backup data init cloud --yes >/dev/null 2>&1 || true
run "$binary" backup timeline --local --json | jq -e '.data.rows | map(select(.id == "files-cloud")) | .[0].error == "not read (--local)"' >/dev/null || fail '--local skips the network targets'

# ---- the screen needs a terminal ----
[[ "$(code "$binary" timemachine)" == 4 ]] || fail 'timemachine without a terminal exits 4'
[[ "$(code "$binary" timemachine extra)" == 2 ]] || fail 'bad usage exits 2'
echo "timeline-test: ok"

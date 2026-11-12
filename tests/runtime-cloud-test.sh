#!/usr/bin/env bash
# `bxcachy layout`, `bxcachy keys mac` and `bxcachy cloud` with fake hyprctl, systemctl, rclone and fusermount3. Usage: runtime-cloud-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/cfg/systemd/user" "$tmp/fake"; export LOG="$tmp/log" FAKE="$tmp/fake"; : > "$LOG"
cat > "$tmp/bin/hyprctl" <<'SH'
#!/usr/bin/env bash
echo "hyprctl $*" >> "$LOG"
case "$1 $2" in
  "activeworkspace -j") echo '{"id": 2}' ;;
  "clients -j") cat "$FAKE/clients.json" ;;
esac
SH
printf '#!/usr/bin/env bash\necho "systemctl $*" >> "$LOG"\n[[ "$2" == is-active ]] && { [[ -e "$FAKE/active.$3" ]] && echo active || echo inactive; }\nexit 0\n' > "$tmp/bin/systemctl"
printf '#!/usr/bin/env bash\n[[ "$1" == listremotes ]] && printf "gdrive:\\nwork-s3:\\n"\n' > "$tmp/bin/rclone"
printf '#!/usr/bin/env bash\n' > "$tmp/bin/fusermount3"
chmod +x "$tmp/bin"/*
run() { env HOME="$tmp/home" XDG_CURRENT_DESKTOP= HYPRLAND_INSTANCE_SIGNATURE="${HYPR:-}" BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_STATE_HOME="$tmp/state" FAKE="$FAKE" LOG="$LOG" PATH="$tmp/bin:$PATH" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
export HYPR=sig

# ---- layout (Hyprland): the windows of workspace 2 only ----
cat > "$FAKE/clients.json" <<'JSON'
[{"address":"0xa1","workspace":{"id":2},"floating":false,"mapped":true},
 {"address":"0xa2","workspace":{"id":2},"floating":true,"mapped":true},
 {"address":"0xb1","workspace":{"id":1},"floating":false,"mapped":true}]
JSON
run "$binary" layout status --json | jq -e '.data.workspace == 2 and .data.windows == 2 and .data.tiled == 1 and .data.floating == 1' >/dev/null || fail "status: $(run "$binary" layout status --json)"
run "$binary" layout toggle --dry-run --json | jq -e '.data.to == "floating" and .data.changed == 1 and .data.commands == [["hyprctl","dispatch","setfloating","address:0xa1"]]' >/dev/null || fail 'toggle with a tiled window floats the tiled ones'
: > "$LOG"; run "$binary" layout toggle | grep -q '1 window(s) on workspace 2 are now floating' || fail 'toggle'
grep -q 'hyprctl dispatch setfloating address:0xa1' "$LOG" && ! grep -q '0xb1' "$LOG" || fail "only workspace 2 changes: $(cat "$LOG")"
cat > "$FAKE/clients.json" <<'JSON'
[{"address":"0xa1","workspace":{"id":2},"floating":true,"mapped":true},{"address":"0xa2","workspace":{"id":2},"floating":true,"mapped":true}]
JSON
run "$binary" layout toggle --dry-run --json | jq -e '.data.to == "tiled" and .data.changed == 2' >/dev/null || fail 'all floating: toggle tiles them'
run "$binary" layout float --dry-run --json | jq -e '.data.changed == 0' >/dev/null || fail 'float with nothing to change'
echo '[]' > "$FAKE/clients.json"; run "$binary" layout | grep -q 'No windows' || fail 'empty workspace'
HYPR= code "$binary" layout toggle | grep -q . || true
[[ "$(HYPR= code "$binary" layout toggle)" == 4 ]] || fail 'no desktop exits 4'
[[ "$(code "$binary" layout sideways)" == 2 ]] || fail 'an unknown mode exits 2'

# ---- keys mac ----
run "$binary" keys mac status --json | jq -e '.data.installed == false and .data.active == false' >/dev/null || fail 'mac status: not set up'
[[ "$(code "$binary" keys mac off --yes)" == 4 ]] || fail 'mac off without the unit exits 4'
touch "$tmp/cfg/systemd/user/xremap.service"
[[ "$(code "$binary" keys mac off)" == 2 ]] || fail 'mac off without --yes exits 2'
: > "$LOG"; run "$binary" keys mac off --yes | grep -q 'off' || fail 'mac off --yes'
grep -q 'systemctl --user disable --now xremap' "$LOG" || fail 'disable command'
run "$binary" keys mac on --yes >/dev/null; grep -q 'systemctl --user enable --now xremap' "$LOG" || fail 'enable command'
touch "$FAKE/active.xremap"; run "$binary" keys mac --json | jq -e '.data.active == true' >/dev/null || fail 'mac status: active'

# ---- cloud ----
run "$binary" cloud remotes --json | jq -e '.data.remotes == ["gdrive","work-s3"]' >/dev/null || fail 'remotes'
unit="$tmp/cfg/systemd/user/bxcachy-cloud-gdrive.service"
[[ "$(code "$binary" cloud mount nope --yes)" == 4 ]] || fail 'an unknown remote exits 4'
[[ "$(code "$binary" cloud mount gdrive --path='/tmp/a b' --yes)" == 4 ]] || fail 'a path with spaces exits 4'
[[ "$(code "$binary" cloud mount gdrive --path=relative --yes)" == 4 ]] || fail 'a relative path exits 4'
[[ "$(code "$binary" cloud mount gdrive)" == 2 ]] || fail 'mount without --yes exits 2'
[[ ! -e "$unit" ]] || fail 'the plan wrote the unit'
: > "$LOG"; run "$binary" cloud mount gdrive --yes | grep -q "gdrive is mounted at $tmp/home/Cloud/gdrive" || fail 'mount --yes'
grep -q '^ExecStart=/usr/bin/rclone mount gdrive: .*/Cloud/gdrive --vfs-cache-mode writes$' "$unit" && grep -q '^Type=notify$' "$unit" && grep -q '^ExecStop=/usr/bin/fusermount3 -u ' "$unit" && grep -q '^WantedBy=default.target$' "$unit" || fail "unit: $(cat "$unit")"
grep -q 'systemctl --user enable --now bxcachy-cloud-gdrive.service' "$LOG" || fail 'the service was enabled and started'
run "$binary" cloud mount gdrive --yes | grep -q 'is mounted' || fail 'mounting again is fine'
touch "$FAKE/active.bxcachy-cloud-gdrive.service"; run "$binary" cloud status --json | jq -e '.data.mounts == [{"remote":"gdrive","active":true}]' >/dev/null || fail 'status'
echo '# mine' >> "$unit"; [[ "$(code "$binary" cloud mount gdrive --path=/data/g --yes)" == 4 ]] || fail 'an edited unit is kept (exit 4)'
grep -q '# mine' "$unit" || fail 'the edited unit was overwritten'
[[ "$(code "$binary" cloud unmount gdrive)" == 2 ]] || fail 'unmount without --yes exits 2'
run "$binary" cloud unmount gdrive --yes --json | jq -e '.data.unit_removed == false' >/dev/null || fail 'an edited unit file is kept on unmount'
[[ -e "$unit" ]] || fail 'the edited unit was deleted'
rm "$unit"; run "$binary" cloud mount work-s3 --path="$tmp/s3" --yes >/dev/null; run "$binary" cloud unmount work-s3 --yes --json | jq -e '.data.unit_removed == true' >/dev/null || fail 'a clean unit file is removed on unmount'
[[ ! -e "$tmp/cfg/systemd/user/bxcachy-cloud-work-s3.service" ]] || fail 'the clean unit file is still there'
mv "$tmp/bin/fusermount3" "$tmp/fm.off"; mkdir -p "$tmp/nobin"; ln -sf "$(command -v sh)" "$tmp/nobin/sh"; ln -sf "$tmp/bin/rclone" "$tmp/nobin/rclone"
set +e; env HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" PATH="$tmp/nobin" "$binary" cloud mount gdrive --yes >/dev/null 2>&1; rc=$?; set -e; [[ "$rc" == 4 ]] || fail "no fuse3 exits 4 (got $rc)"
echo "runtime-cloud-test: ok"

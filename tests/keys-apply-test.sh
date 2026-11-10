#!/usr/bin/env bash
# `bxcachy keys check|apply` and the shortcut files in `config`, with fake kreadconfig6/kwriteconfig6. Usage: keys-apply-test.sh [binary]
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/cfg" "$tmp/state" "$tmp/kg"
cat > "$tmp/bin/kreadconfig6" <<'MOCK'
#!/usr/bin/env bash
[[ "$1" == --version ]] && exit 0
[[ -f "$KG/${@: -1}" ]] && cat "$KG/${@: -1}" || true
MOCK
cat > "$tmp/bin/kwriteconfig6" <<'MOCK'
#!/usr/bin/env bash
[[ "$1" == --version ]] && exit 0
printf '%s' "${@: -1}" > "$KG/${@: -2:1}"
MOCK
printf '#!/usr/bin/env bash\nif [[ "$1" == -u ]]; then echo "${MOCK_UID:-1000}"; else /usr/bin/id "$@"; fi\n' > "$tmp/bin/id"
chmod +x "$tmp/bin/"*
run() { env HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_STATE_HOME="$tmp/state" KG="$tmp/kg" PATH="$tmp/bin:$PATH" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

[[ "$(code "$binary" keys check)" == 1 ]] || fail 'check before apply exits 1'
[[ "$(code "$binary" keys apply)" == 2 ]] || fail 'apply without --yes exits 2'
[[ ! -e "$tmp/cfg/xremap/config.yml" ]] || fail 'apply without --yes wrote a file'
[[ "$(MOCK_UID=0 code "$binary" keys apply --yes)" == 4 ]] || fail 'root exits 4'
[[ "$(code "$binary" keys apply --yes --dry-run)" == 0 ]] || fail 'dry run exits 0'
[[ ! -e "$tmp/cfg/xremap/config.yml" && ! -s "$tmp/kg/Log Out" ]] || fail 'dry run changed something'
[[ "$(code "$binary" keys apply --yes)" == 0 ]] || fail 'apply --yes exits 0'
grep -q 'Super-c: Ctrl-Shift-c' "$tmp/cfg/xremap/config.yml" || fail 'xremap file written'
grep -q 'uwsm stop' "$tmp/cfg/hypr/bxcachy-keys.conf" || fail 'hypr file written'
[[ "$(cat "$tmp/kg/Log Out")" == "Meta+Shift+Q,Ctrl+Alt+Del,Log Out" ]] || fail 'plasma shortcut set'
[[ "$(code "$binary" keys check)" == 0 ]] || fail 'check after apply exits 0'
run "$binary" keys check --json | jq -e '.ok and (.data.items | length) == 4' >/dev/null || fail 'check --json'
run "$binary" config list | grep -q '^xremap: clean' || fail 'config list shows xremap'
[[ "$(code "$binary" keys apply --yes)" == 0 ]] || fail 're-run exits 0'
# drift
echo '# mine' >> "$tmp/cfg/xremap/config.yml"
[[ "$(code "$binary" keys check)" == 1 ]] || fail 'drifted file exits 1'
[[ "$(code "$binary" keys apply --yes)" == 8 ]] || fail 'apply on drift exits 8 without --force'
grep -q '# mine' "$tmp/cfg/xremap/config.yml" || fail 'drift was overwritten without --force'
[[ "$(code "$binary" keys apply --yes --force)" == 0 ]] || fail '--force overwrites'
! grep -q '# mine' "$tmp/cfg/xremap/config.yml" || fail 'force did not overwrite'
echo "keys apply tests passed"

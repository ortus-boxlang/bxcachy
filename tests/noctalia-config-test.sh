#!/usr/bin/env bash
# The Noctalia starter files through `config apply`: valid TOML and JSON, safe re-runs, drift. Usage: noctalia-config-test.sh [binary]
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/home"
run() { env HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_STATE_HOME="$tmp/state" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
run "$binary" config list | grep -q '^noctalia: missing' || fail 'config list shows noctalia as missing'
[[ "$(code "$binary" config apply noctalia)" == 2 ]] || fail 'apply without --yes exits 2'
[[ ! -e "$tmp/cfg/noctalia" ]] || fail 'apply without --yes wrote a file'
[[ "$(code "$binary" config apply noctalia --yes)" == 0 ]] || fail 'apply noctalia'
[[ "$(code "$binary" config apply noctalia-palette --yes)" == 0 ]] || fail 'apply noctalia-palette'
python3 - "$tmp/cfg/noctalia/config.toml" "$tmp/home" <<'PY' || fail 'config.toml is not valid TOML or lacks the expected keys'
import sys, tomllib
c = tomllib.load(open(sys.argv[1], 'rb'))
assert c['theme']['custom_palette'] == 'BxCachy' and c['theme']['source'] == 'custom'
assert c['bar']['order'] == ['main'] and c['bar']['main']['position'] == 'top'
assert 'launcher' in c['bar']['main']['start'] and 'clock' in c['bar']['main']['center']
assert 'media' in c['bar']['main']['center'] and 'media' not in c['bar']['main']['end']
for name in ('clock-lax', 'clock-nyc', 'clock-lon', 'clock-mad'):
    assert name in c['bar']['main']['center'] and c['widget'][name]['type'] == 'clock' and c['widget'][name]['timezone']
assert c['wallpaper']['directory'] == sys.argv[2] + '/Pictures/BxCachy'
assert c['wallpaper']['default']['path'].endswith('/box.jpg')
PY
jq -e '.version == 2 and (.dark | has("primary","surface","hover")) and (.light | has("primary")) and (.dark.terminal.normal | length) == 8' "$tmp/cfg/noctalia/palettes/BxCachy.json" >/dev/null || fail 'palette is not valid or lacks keys'
run "$binary" config list | grep -q '^noctalia: clean' || fail 'config list shows noctalia clean'
echo '# mine' >> "$tmp/cfg/noctalia/config.toml"
[[ "$(code "$binary" config apply noctalia --yes)" == 8 ]] || fail 'drift exits 8 without --force'
[[ "$(code "$binary" config apply noctalia --yes --force)" == 0 ]] || fail '--force overwrites'
echo "noctalia config tests passed"

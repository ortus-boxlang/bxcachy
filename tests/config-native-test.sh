#!/usr/bin/env bash
# Tests for `bxrig config` in the compiled binary. Usage: config-native-test.sh [path-to-binary]
set -euo pipefail
bin="$(cd "$(dirname "${1:-./bxrig}")" && pwd)/$(basename "${1:-./bxrig}")"
test -x "$bin"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"; mkdir -p "$HOME"
target="$HOME/.config/bxrig/bxrig.json"
state="$HOME/.local/state/bxrig"
fail() { echo "FAIL: $*" >&2; exit 1; }
code() { set +e; "$@" >"$tmp/out" 2>&1; rc=$?; set -e; echo "$rc"; }

[[ "$(code "$bin" config list)" == 0 ]]; grep -Fq 'bxrig: missing' "$tmp/out" || fail list-missing
[[ "$(code "$bin" config apply bxrig)" == 2 ]] || fail 'apply without --yes must exit 2'
[[ ! -e "$target" ]] || fail 'unconfirmed apply wrote'
[[ "$(code "$bin" config apply bxrig --yes --dry-run)" == 0 ]]; [[ ! -e "$target" ]] || fail 'dry run wrote'
[[ "$(code "$bin" config apply bxrig --yes)" == 0 ]]; [[ "$(stat -c %a "$target")" == 600 ]] || fail mode
[[ "$(ls "$state/journal" | wc -l)" == 1 ]] || fail 'journal count after first apply'
[[ ! -d "$state/backups" ]] || fail 'no backup expected when target was missing'
[[ "$(code "$bin" config apply bxrig --yes)" == 0 ]]; grep -Fq unchanged "$tmp/out" || fail 'second apply not a no-op'
[[ "$(ls "$state/journal" | wc -l)" == 1 ]] || fail 'no-op wrote a journal entry'
# drift: user edits the file
echo '{"user":"edit"}' > "$target"
"$bin" config list | grep -Fq 'bxrig: drifted' || fail 'drift not detected'
[[ "$(code "$bin" config apply bxrig --yes)" == 8 ]] || fail 'drifted apply must exit 8'
grep -Fq '"user":"edit"' "$target" || fail 'drifted file was overwritten'
"$bin" config diff bxrig | grep -Fq 'schema_version' || fail 'diff shows nothing'
[[ "$(code "$bin" config apply bxrig --yes --force)" == 0 ]] || fail 'force apply'
grep -Fq schema_version "$target" || fail 'force did not write'
backup="$(find "$state/backups" -name '*.bak' | head -1)"
[[ -n "$backup" && "$(cat "$backup")" == '{"user":"edit"}' ]] || fail 'backup content'
# restore
id="$("$bin" config history bxrig | awk '$2=="apply"{print $1}' | head -1)"
[[ "$(code "$bin" config restore bxrig "$id")" == 2 ]] || fail 'restore without --yes must exit 2'
[[ "$(code "$bin" config restore bxrig "$id" --yes)" == 0 ]] || fail 'restore'
[[ "$(cat "$target")" == '{"user":"edit"}' ]] || fail 'restore content'
[[ "$(code "$bin" config restore bxrig nonsense --yes)" == 3 ]] || fail 'unknown id must exit 3'
# symlink refusal
rm "$target"; ln -s "$tmp/elsewhere" "$target"
[[ "$(code "$bin" config apply bxrig --yes)" == 8 ]] || fail 'symlink target must exit 8'
[[ ! -e "$tmp/elsewhere" ]] || fail 'wrote through symlink'
rm "$target"
# lock
touch "$state/lock"
[[ "$(code "$bin" config apply bxrig --yes)" == 8 ]] || fail 'held lock must exit 8'
rm "$state/lock"
[[ "$(code "$bin" config apply bxrig --yes)" == 0 ]]
[[ ! -e "$state/lock" ]] || fail 'lock not released'
# usage errors
[[ "$(code "$bin" config)" == 2 ]]; [[ "$(code "$bin" config bogus)" == 2 ]]
[[ "$(code "$bin" config apply nope --yes)" == 2 ]]; [[ "$(code "$bin" config list --bogus)" == 2 ]]
[[ "$(code "$bin" config apply bxrig extra --yes)" == 2 ]]
# json
"$bin" config list --json | grep -Fq '"state"' || fail 'list --json'
# retention: 25 forced rewrites keep at most 20 entries
for i in $(seq 1 25); do echo "{\"n\":$i}" > "$target"; "$bin" config apply bxrig --yes --force >/dev/null; done
[[ "$(ls "$state/journal" | wc -l)" -le 20 ]] || fail 'retention'
echo 'config native tests passed'

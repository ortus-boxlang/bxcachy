#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
printf 'old\n' > "$tmp/target"
printf 'new\n' > "$tmp/source"
bash "$root/scripts/config.sh" apply "$tmp/source" "$tmp/target" --yes
[[ "$(cat "$tmp/target")" == new ]]
backup="$(find "$tmp" -name '*.bak' -print -quit)"
[[ -n "$backup" && "$(cat "$backup")" == old ]]
count="$(find "$tmp" -name '*.bak' | wc -l)"
bash "$root/scripts/config.sh" apply "$tmp/source" "$tmp/target" --yes | grep -F unchanged
[[ "$(find "$tmp" -name '*.bak' | wc -l)" == "$count" ]]
bash "$root/scripts/config.sh" restore "$backup" "$tmp/target" --yes
[[ "$(cat "$tmp/target")" == old ]]
if bash "$root/scripts/config.sh" apply "$tmp/source" "$tmp/target" >/dev/null 2>&1; then echo 'FAIL: unconfirmed apply' >&2; exit 1; fi
ln -s "$tmp/target" "$tmp/link"
if bash "$root/scripts/config.sh" apply "$tmp/source" "$tmp/link" --yes >/dev/null 2>&1; then echo 'FAIL: symlink destination' >&2; exit 1; fi
echo 'config tests passed'

#!/usr/bin/env bash
# Embeds catalog/apps.json into src/bxcachy.bxs between the GENERATED CATALOG markers.
# The compiled binary has no data files, so the catalog travels inside the source.
#   gen-catalog.sh           rewrite src/bxcachy.bxs
#   gen-catalog.sh --check   fail if src/bxcachy.bxs is out of date (CI)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
src="$root/src/bxcachy.bxs"
command -v jq >/dev/null || { echo 'jq is required' >&2; exit 4; }
json="$(jq -c . "$root/catalog/apps.json")"
[[ "$json" != *\\* ]] || { echo "catalog contains a backslash; MatchBox string literals do not keep it, remove it" >&2; exit 4; }
# BoxLang single-quoted strings: double any quote, and double # (interpolation).
lit="${json//\'/\'\'}"; lit="${lit//#/##}"
block="$(printf '%s\n%s\n%s\n%s\n' \
  '// BEGIN GENERATED CATALOG (bootstrap/gen-catalog.sh, do not edit by hand)' \
  'function catalogJson() {' \
  " return '${lit}';" \
  '}')"
block+=$'\n// END GENERATED CATALOG'
new="$(awk -v block="$block" '
  /^\/\/ BEGIN GENERATED CATALOG/ { print block; skip=1; next }
  /^\/\/ END GENERATED CATALOG/ { skip=0; next }
  !skip { print }' "$src")"
grep -q 'BEGIN GENERATED CATALOG' "$src" || { echo "markers missing in $src" >&2; exit 4; }
if [[ "${1:-}" == --check ]]; then
  [[ "$new" == "$(cat "$src")" ]] || { echo 'src/bxcachy.bxs catalog is out of date: run bootstrap/gen-catalog.sh' >&2; exit 1; }
  echo 'catalog embed is current'
else
  printf '%s\n' "$new" > "$src"
  echo "embedded $(jq '.apps|length' "$root/catalog/apps.json") apps into src/bxcachy.bxs"
fi

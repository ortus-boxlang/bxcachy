#!/usr/bin/env bash
# Idempotent, atomic user configuration deployment with backup and restore.
set -euo pipefail
usage() { echo "Usage: config.sh apply SOURCE DESTINATION --yes | restore BACKUP DESTINATION --yes" >&2; exit 2; }
[[ $# -eq 4 && "$4" == --yes ]] || usage
action="$1"; source="$2"; destination="$3"
[[ "$action" == apply || "$action" == restore ]] || usage
[[ -f "$source" && ! -L "$source" ]] || { echo "Source must be a regular file" >&2; exit 2; }
[[ "$destination" = /* && "$destination" != / && ! -L "$destination" ]] || { echo "Destination must be an absolute, non-symlink file path" >&2; exit 2; }
parent="$(dirname -- "$destination")"
[[ -d "$parent" && ! -L "$parent" ]] || { echo "Destination parent must exist and not be a symlink" >&2; exit 2; }
if [[ -e "$destination" && ! -f "$destination" ]]; then echo "Destination is not a regular file" >&2; exit 2; fi
if [[ -f "$destination" ]] && cmp -s -- "$source" "$destination"; then echo "unchanged: $destination"; exit 0; fi
temp="$(mktemp "$parent/.bxrig.XXXXXXXX")"
trap 'rm -f -- "$temp"' EXIT
cat -- "$source" > "$temp"
chmod --reference="$source" "$temp"
if [[ -f "$destination" ]]; then
  backup="$destination.bxrig.$(date -u +%Y%m%dT%H%M%SZ).$$.bak"
  cp -p -- "$destination" "$backup"
  echo "backup: $backup"
fi
mv -f -- "$temp" "$destination"
trap - EXIT
echo "$action: $destination"

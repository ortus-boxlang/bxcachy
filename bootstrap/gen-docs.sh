#!/usr/bin/env bash
# Rewrites docs/reference/commands.md from the "Usage:" lines in src/Main.bx.
#   gen-docs.sh           rewrite
#   gen-docs.sh --check   fail if it is out of date (CI)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
python3 - "$root" > "$tmp" <<'PY'
import re,sys
root=sys.argv[1]
s=open(root+'/src/Main.bx').read()
us=[]
for u in re.findall(r'println\(\s*"Usage: bxcachy ([^"]*)"',s):
    if u.strip() and u not in us: us.append(u)
rows=sorted((u.split()[0],u) for u in us)
out=['---','title: Command reference','order: 1','summary: Every command, from the program itself.','---','','# Command reference','',
'Generated from the usage text in `src/Main.bx` (`bootstrap/gen-docs.sh` rewrites it). Every command accepts `--json`; commands that change the system print a plan and need `--yes`, and `--dry-run` shows the plan and exits 0. See the [command contract](../architecture/COMMAND-CONTRACT.md) for exit codes and details.','']
for name,u in rows:
    out+=['### `bxcachy %s`'%name,'','```text','bxcachy '+u,'```','']
print('\n'.join(out))
PY
if [[ "${1:-}" == --check ]]; then
  cmp -s "$tmp" "$root/docs/reference/commands.md" && echo "command reference is current" || { echo "docs/reference/commands.md is out of date: run bootstrap/gen-docs.sh" >&2; exit 1; }
else
  cp "$tmp" "$root/docs/reference/commands.md"; echo "wrote docs/reference/commands.md"
fi

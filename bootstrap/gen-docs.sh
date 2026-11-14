#!/usr/bin/env bash
# Builds the command reference from docs/reference/cli.json (the curated data: group, summary, usage, examples, notes):
#   docs/reference/commands.md   the page on the docs site
#   src/bxrig/HelpData.bx      the same data inside the program, for `bxrig help` and `bxrig help COMMAND`
# It also fails when a command in src/Main.bx has no entry (or an entry has no command), or an example names a command that does not exist.
#   gen-docs.sh           rewrite both files
#   gen-docs.sh --check   fail if they are out of date or the data and Main.bx disagree (CI)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT
python3 - "$root" "$tmpdir" <<'PY'
import json,re,sys
root,out=sys.argv[1],sys.argv[2]
d=json.load(open(root+'/docs/reference/cli.json'))
src=open(root+'/src/Main.bx').read()
routes=[]
for r in re.findall(r'case "([a-z0-9-]+)":',src):
    if r not in routes: routes.append(r)
names=[c['name'] for g in d['groups'] for c in g['commands']]
problems=[]
for r in routes:
    if r not in names: problems.append('no entry in cli.json for the command: '+r)
for n in names:
    if n not in routes: problems.append('cli.json has an entry for a command that does not exist: '+n)
    if names.count(n)>1: problems.append('listed twice: '+n)
for g in d['groups']:
    for c in g['commands']:
        for u in c['usage']:
            if u.split()[0]!=c['name']: problems.append('usage of %s starts with %s'%(c['name'],u.split()[0]))
        for e in c['examples']:
            w=e.split()
            if w[0]!='bxrig' or len(w)<2 or w[1] not in routes: problems.append('example of %s names no command: %s'%(c['name'],e))
        if not c['summary'].endswith('.'): problems.append('the summary of %s should end with a full stop'%c['name'])
        if '—' in json.dumps(c,ensure_ascii=False): problems.append('em dash in '+c['name'])
if problems:
    sys.stderr.write('\n'.join(problems)+'\n'); sys.exit(1)

def anchor(n): return 'bxrig-'+n
L=['---','title: Command reference','order: 1','summary: Every bxrig command with its usage, examples and exit codes.','---','',
'# Command reference','',
'Every command is `bxrig NAME ...`. This page is generated from `docs/reference/cli.json`; the same data answers `bxrig help` and `bxrig help NAME` in the terminal. The [command contract](../architecture/COMMAND-CONTRACT.md) has the details behind each one.','',
'## How commands behave','',
'| Flag | What it does |','|---|---|',
'| `--json` | Print one JSON object instead of text (see below). Every command takes it. |',
'| `--yes` | Apply a change that installs packages or edits system files. Without it you get the plan and exit code 2. |',
'| `--dry-run` | Print the plan or the exact commands and exit 0. Nothing is changed. |',
'| `--force` | Where it exists: replace a file BxRig would otherwise keep because you edited it. |','',
'Settings that only touch your own config (a theme, the bar, the font) act at once and need no `--yes`.','',
'### Exit codes','',
'| Code | Meaning |','|---|---|',
'| 0 | Done, or nothing to do (also `--dry-run`). |',
'| 1 | A check came out negative (for example `package-status` says it is missing). |',
'| 2 | Usage error, or a plan was printed because `--yes` was not given. |',
'| 3 | Timeout, or the item is not available. |',
'| 4 | A precondition failed: not Arch or CachyOS, a tool or a monitor that is not there, an unknown name. |',
'| 5 | The official (pacman) phase failed. |',
'| 6 | The AUR phase, or the command you asked for, failed. |',
'| 7 | Partial success: some items were done, some failed. |',
'| 8 | Config conflict: a file you edited, or another run is in progress. |',
'| 9 | Internal error. |',
'| 10 | `update check`: an update is available. |','',
'### JSON','',
'```json','{ "schema": 1, "command": "dns", "version": "0.11.0", "ok": true, "exit": 0, "dry_run": false, "data": { }, "warnings": [] }','```','',
'`data` is different for every command; `ok` is true when `exit` is 0. Scripts should read `exit` and `data`, never the text.','',
'## All commands','']
for g in d['groups']:
    L+=['**%s**: %s'%(g['title'],', '.join('[`%s`](#%s)'%(c['name'],anchor(c['name'])) for c in g['commands'])),'']
for g in d['groups']:
    L+=['## '+g['title'],'',g['blurb'],'']
    for c in g['commands']:
        L+=['### `bxrig %s` {#%s}'%(c['name'],anchor(c['name'])),'',c['summary'],'']
        L+=['```text']+['bxrig '+u for u in c['usage']]+['```','']
        if c['mutates']: L+=['Changes the system: needs `--yes`. Without it you get the plan (exit 2); `--dry-run` shows it and exits 0.','']
        if c['examples']: L+=['```bash']+c['examples']+['```','']
        if c.get('note'): L+=['> '+c['note'],'']
open(out+'/commands.md','w').write('\n'.join(L).rstrip('\n')+'\n')
compact=json.dumps(d,ensure_ascii=False,separators=(',',':'))
if '\\' in compact: sys.stderr.write('cli.json contains a backslash; remove it\n'); sys.exit(1)
lit=compact.replace("'","''").replace('#','##')
open(out+'/HelpData.bx','w').write("// GENERATED by bootstrap/gen-docs.sh from docs/reference/cli.json. Do not edit by hand.\nclass HelpData {\n    function json() {\n        return '%s';\n    }\n}\n"%lit)
PY
if [[ "${1:-}" == --check ]]; then
  ok=1
  cmp -s "$tmpdir/commands.md" "$root/docs/reference/commands.md" || { echo "docs/reference/commands.md is out of date: run bootstrap/gen-docs.sh" >&2; ok=0; }
  cmp -s "$tmpdir/HelpData.bx" "$root/src/bxrig/HelpData.bx" || { echo "src/bxrig/HelpData.bx is out of date: run bootstrap/gen-docs.sh" >&2; ok=0; }
  [[ $ok == 1 ]] && echo "command reference is current" || exit 1
else
  cp "$tmpdir/commands.md" "$root/docs/reference/commands.md"; cp "$tmpdir/HelpData.bx" "$root/src/bxrig/HelpData.bx"
  echo "wrote docs/reference/commands.md and src/bxrig/HelpData.bx"
fi

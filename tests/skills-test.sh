#!/usr/bin/env bash
# `bxcachy skills` with a fake skills hub (curl) and fake agents. Usage: skills-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/nobin"; export LOG="$tmp/log"; : > "$LOG"
# the fake hub: list and search, show, and install (content per skill; "blocked" fails its audit with 403, "missing" is 404)
cat > "$tmp/bin/curl" <<'CURL'
#!/usr/bin/env bash
echo "curl $*" >> "$LOG"
args="$*"; post=""; body=""
while [ $# -gt 0 ]; do case "$1" in -d) body="$2"; shift ;; -X) post="$2"; shift ;; esac; shift; done
if [[ "$args" == */api/install* ]]; then
  case "$body" in
    *blocked*) printf '{"data":{}}\n403'; exit 0 ;;
    *missing*) printf '{"data":{}}\n404'; exit 0 ;;
    *matchbox*) name=boxlang-runtime-matchbox ;;
    *) name=boxlang-language-fundamentals ;;
  esac
  python3 - "$name" <<'PY'
import json,sys
n=sys.argv[1]
print(json.dumps({"data":{"skill":{"skill_slug":"x"},"content":"---\nname: %s\ndescription: \"d\"\n---\n\n# %s\n"%(n,n),"audit":{"status":"trusted","score":100,"findings":[]},"counts":{}}}))
print(200,end="")
PY
  exit 0
fi
case "$args" in
  */api/skills/ortus-boxlang/skills/*) echo '{"error":false,"data":{"skill_name":"language-fundamentals","description":"BoxLang basics","audit_status":"trusted"}}' ;;
  */api/skills\?*) echo '{"data":{"data":[{"owner":"ortus-boxlang","repo":"skills","skill_slug":"boxlang-developer~runtime-matchbox","skill_name":"runtime-matchbox","description":"MatchBox runtime","category":"boxlang-developer","audit_status":"trusted"}],"total":1}}' ;;
  *) exit 22 ;;
esac
CURL
for t in claude codex; do printf '#!/bin/sh\n' > "$tmp/bin/$t"; done
chmod +x "$tmp/bin"/*
run() { env HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_SKILLS_URL=http://hub PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

# the hub: search and show
run "$binary" skills search matchbox | grep -q 'ortus-boxlang/skills/boxlang-developer~runtime-matchbox  \[trusted\]' || fail 'search'
grep -q 'api/skills?perPage=100&sort=newest&search=matchbox' "$LOG" || fail "search url: $(cat "$LOG")"
run "$binary" skills list --json | jq -e '.data.skills[0].name == "runtime-matchbox"' >/dev/null || fail 'list'
run "$binary" skills show ortus-boxlang/skills/boxlang-developer~language-fundamentals | grep -q 'BoxLang basics' || fail 'show'
run "$binary" skills show ortus-boxlang/skills/boxlang-developer/language-fundamentals >/dev/null || fail 'the CATEGORY/NAME form is accepted'
[[ "$(code "$binary" skills show nonsense)" == 4 ]] || fail 'a bad reference exits 4'

# install: a plan first, then the five BxCachy skills, BoxLang and MatchBox
[[ "$(code "$binary" skills install bxcachy)" == 2 ]] || fail 'install without --yes exits 2'
[[ ! -d "$tmp/home/.agents" ]] || fail 'a plan wrote something'
run "$binary" skills install bxcachy boxlang matchbox --yes | grep -q 'Installed skills' || fail 'install'
for n in bxcachy bxcachy-ai bxcachy-apps bxcachy-desktop bxcachy-system bxcachy-install-update boxlang-language-fundamentals boxlang-runtime-matchbox; do [[ -f "$tmp/home/.agents/skills/$n/SKILL.md" ]] || fail "$n was not stored"; done
head -2 "$tmp/home/.agents/skills/bxcachy/SKILL.md" | grep -q '^name: bxcachy$' || fail 'the embedded skill has its frontmatter'
grep -q 'audit' "$tmp/cfg/bxcachy/skills.json" && jq -e '.skills.bxcachy.source == "embedded" and .skills["boxlang-runtime-matchbox"].source == "hub"' "$tmp/cfg/bxcachy/skills.json" >/dev/null || fail 'manifest'
# linked into the agents that exist (claude and codex here), as symlinks to the store
[[ -L "$tmp/home/.claude/skills/bxcachy" && -L "$tmp/home/.codex/skills/boxlang-runtime-matchbox" ]] || fail 'links into claude and codex'
[[ ! -e "$tmp/home/.gemini" && ! -e "$tmp/home/.config/opencode" ]] || fail 'agents that are not installed got nothing'
# a folder of yours is never replaced
rm "$tmp/home/.claude/skills/bxcachy-ai"; mkdir "$tmp/home/.claude/skills/bxcachy-ai"; echo mine > "$tmp/home/.claude/skills/bxcachy-ai/SKILL.md"
run "$binary" skills link >/dev/null; grep -q '^mine$' "$tmp/home/.claude/skills/bxcachy-ai/SKILL.md" && [[ ! -L "$tmp/home/.claude/skills/bxcachy-ai" ]] || fail 'your own skill folder was replaced'
# a blocked or missing skill is refused and nothing of it is written
[[ "$(code "$binary" skills install ortus-boxlang/skills/cat~blocked --yes)" == 5 ]] || fail 'a skill that failed its audit exits 5'
{ run "$binary" skills install ortus-boxlang/skills/cat~blocked --yes 2>&1 || true; } | grep -q 'security audit' || fail 'the audit message'
[[ "$(code "$binary" skills install ortus-boxlang/skills/cat~missing --yes)" == 5 ]] || fail 'a missing skill exits 5'
# installed, status, update, remove
run "$binary" skills installed | grep -q 'boxlang-runtime-matchbox  (hub: ortus-boxlang/skills/boxlang-developer~runtime-matchbox)' || fail 'installed'
run "$binary" skills status --json | jq -e '.data.skills == 8 and (.data.agents | map(select(.present)) | length) == 2' >/dev/null || fail 'status'
: > "$LOG"; run "$binary" skills update --yes >/dev/null; grep -q 'api/install' "$LOG" || fail 'update fetches the hub skills again'
[[ "$(code "$binary" skills remove bxcachy)" == 2 ]] || fail 'remove without --yes exits 2'
run "$binary" skills remove boxlang-runtime-matchbox --yes >/dev/null
[[ ! -e "$tmp/home/.agents/skills/boxlang-runtime-matchbox" && ! -e "$tmp/home/.claude/skills/boxlang-runtime-matchbox" ]] || fail 'remove deletes the skill and its links'
[[ "$(code "$binary" skills remove nope --yes)" == 4 ]] || fail 'removing an unknown skill exits 4'
# the hub is down
rm "$tmp/bin/curl"; printf '#!/bin/sh\nexit 7\n' > "$tmp/bin/curl"; chmod +x "$tmp/bin/curl"; [[ "$(code "$binary" skills search x)" == 5 ]] || fail 'hub down exits 5'
[[ "$(code "$binary" skills nope)" == 2 ]] || fail 'usage exits 2'
echo "skills-test ok"

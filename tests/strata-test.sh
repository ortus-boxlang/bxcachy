#!/usr/bin/env bash
# `bxrig strata integrations` with a fake curl. Usage: strata-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home"
printf '#!/usr/bin/env bash\nall="$*"\necho "curl $all" >> "$LOG"\nwhile [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift ;; esac; shift; done\ncase "$all" in *"${FAILURL:-@@none@@}"*) exit 22 ;; esac\necho "fake" > "$out"\n' > "$tmp/bin/curl"
printf '#!/bin/sh\nexit 0\n' > "$tmp/bin/python3"; chmod +x "$tmp/bin"/*
export LOG="$tmp/log"; : > "$LOG"
run() { env HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/cfg" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }

run "$binary" strata integrations --dry-run --json | jq -e '.dry_run and (.data.install | length) == 2' >/dev/null || fail 'dry run lists both'
[[ ! -d "$tmp/cfg/strata" ]] || fail 'dry run wrote something'
run "$binary" strata integrations | grep -q 'installed: kdeconnect, localsend' || fail 'install'
for id in kdeconnect localsend; do
  for f in provider.py messages.json LICENSE provider.json; do [[ -f "$tmp/cfg/strata/providers/$id/$f" ]] || fail "$id/$f missing"; done
  jq -e --arg id "$id" '.version == 1 and .id == $id and (.command[0] | startswith("/")) and (.command[1] | endswith("/provider.py"))' "$tmp/cfg/strata/providers/$id/provider.json" >/dev/null || fail "$id provider.json"
done
grep -q 'lgse/strata/5f17c9fdc8967e1b4ba8aaf8de113b46d824b0dd/integrations/kdeconnect/provider.py' "$LOG" || fail 'download is pinned to the commit'
# again: nothing replaced
echo mine > "$tmp/cfg/strata/providers/localsend/provider.py"
run "$binary" strata integrations | grep -q 'already there' || fail 'kept message'
grep -q '^mine$' "$tmp/cfg/strata/providers/localsend/provider.py" || fail 'an existing provider was overwritten'
# a failed download leaves nothing half done
rm -rf "$tmp/cfg"
rc=0; FAILURL='localsend/LICENSE' run "$binary" strata integrations >/dev/null 2>&1 || rc=$?
[[ "$rc" == 6 ]] || fail "a failed download exits 6 (got $rc)"
[[ -d "$tmp/cfg/strata/providers/kdeconnect" && ! -d "$tmp/cfg/strata/providers/localsend" ]] || fail 'the failed provider left a folder behind'
ls -A "$tmp/cfg/strata/providers" | grep -q '^\.' && fail 'a temp folder was left behind' || true
echo "strata-test ok"

#!/usr/bin/env bash
# `bxcachy help` and `bxcachy help COMMAND`: the list, one command, JSON, unknown. Usage: help-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
root="$(cd "$(dirname "$binary")/.." && pwd)"
fail() { echo "FAIL: $*" >&2; exit 1; }
out="$("$binary" help)"
for g in "Start here" "Install and remove" "Desktop setup" "Look and feel" "System and security" "Develop" "Everyday tools"; do grep -q "^$g:" <<<"$out" || fail "the list has no group: $g"; done
grep -q '^  appearance ' <<<"$out" && grep -q '^  time ' <<<"$out" && grep -q '^  security ' <<<"$out" || fail 'new commands are listed'
# bare `bxcachy` shows the same list
[[ "$("$binary")" == "$out" ]] || fail 'no command shows the help'
# every command of Main.bx is in the list (the generator checks it too)
for r in $(grep -oE 'case "[a-z0-9-]+":' "$root/src/Main.bx" | sed 's/case "//; s/"://' | sort -u); do grep -q "^  $r " <<<"$out" || fail "the help does not list: $r"; done
one="$("$binary" help time)"
grep -q '^bxcachy time: ' <<<"$one" && grep -q '^  bxcachy time zone' <<<"$one" && grep -q 'bxcachy time sync --yes' <<<"$one" || fail "help time: $one"
grep -q 'Changes the system: needs --yes' <<<"$one" || fail 'help says when --yes is needed'
! grep -q 'Changes the system' <<<"$("$binary" help appearance)" || fail 'appearance acts at once, so it does not claim to need --yes'
"$binary" help time --json | jq -e '.ok and .data.command.name == "time" and (.data.command.examples | length > 0)' >/dev/null || fail 'help --json'
"$binary" help --json | jq -e '(.data.groups | length == 7) and ([.data.groups[].commands[]] | length >= 80)' >/dev/null || fail 'help list --json'
set +e; "$binary" help nonsense >/dev/null 2>&1; c=$?; set -e; [[ $c == 2 ]] || fail "unknown command exits 2 (got $c)"
# the docs page and the embedded data are current
bash "$root/bootstrap/gen-docs.sh" --check >/dev/null || fail 'docs/reference/commands.md or HelpData.bx is stale'
echo "help-test: ok"

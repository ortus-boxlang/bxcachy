#!/usr/bin/env bash
# `bxcachy ai list|default|launch` with fake agent commands and terminals. Usage: ai-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/cfg/bxcachy"
export LOG="$tmp/log"; : > "$LOG"
# a fake terminal that logs how it was started
for t in ghostty kitty; do printf '#!/usr/bin/env bash\necho "%s $*" >> "$LOG"\n' "$t" > "$tmp/bin/$t"; chmod +x "$tmp/bin/$t"; done
printf '#!/usr/bin/env bash\necho claude-ran\n' > "$tmp/bin/claude"; chmod +x "$tmp/bin/claude"
run() { env -u ANTHROPIC_API_KEY -u OPENAI_API_KEY -u GEMINI_API_KEY HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_DATA_HOME="$tmp/data" BXCACHY_SELF=bxcachy LOG="$LOG" PATH="$tmp/bin:$PATH" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
ai() { run "$binary" ai "$@"; }
printf '{"backend":"file"}\n' > "$tmp/cfg/bxcachy/secrets.json"

# list: only claude is "installed" (a fake on PATH); nothing is the default yet
ai list --json | jq -e '(.data.agents | length) == 3 and (.data.agents[0].id == "claude-code") and .data.agents[0].installed == true and (.data.agents[1].installed == false) and .data.default == ""' >/dev/null || fail "list: $(ai list --json)"
ai list | grep -q 'claude-code.*installed' || fail 'list text'

# default: unknown 4, not installed 4, plan 2, apply 0, show
[[ "$(code "$binary" ai default nope --yes)" == 4 ]] || fail 'an unknown agent exits 4'
[[ "$(code "$binary" ai default codex-cli --yes)" == 4 ]] || fail 'an agent that is not installed exits 4'
[[ "$(code "$binary" ai default claude-code)" == 2 ]] || fail 'default without --yes exits 2'
[[ ! -e "$tmp/cfg/bxcachy/ai.json" ]] || fail 'the plan wrote the setting'
ai default claude-code --yes | grep -q 'now your default coding agent' || fail 'default --yes'
ai default | grep -q 'Default agent: claude-code' || fail 'default shows the setting'
ai list --json | jq -e '.data.default == "claude-code" and .data.agents[0].default == true' >/dev/null || fail 'list marks the default'

# launch: the default agent opens in the terminal named first in xdg-terminals.list, wrapped in `secrets run` for its own key
[[ "$(code "$binary" ai launch codex-cli)" == 4 ]] || fail 'launching an agent that is not installed exits 4'
printf 'com.mitchellh.ghostty.desktop\n' > "$tmp/cfg/xdg-terminals.list"
ai launch --dry-run --json | jq -e '.data.terminal == "ghostty" and .data.command == ["ghostty","-e","bxcachy","secrets","run","ANTHROPIC_API_KEY","--","claude"]' >/dev/null || fail "dry-run: $(ai launch --dry-run --json)"
[[ ! -s "$LOG" ]] || fail 'dry-run started the terminal'
ai launch | grep -q 'Opened Claude Code in ghostty' || fail 'launch'
for _ in 1 2 3 4 5 6 7 8 9 10; do [[ -s "$LOG" ]] && break; sleep 0.3; done
grep -q '^ghostty -e bxcachy secrets run ANTHROPIC_API_KEY -- claude$' "$LOG" || fail "terminal was started with: $(cat "$LOG")"
printf 'kitty.desktop\n' > "$tmp/cfg/xdg-terminals.list"
ai launch --dry-run --json | jq -e '.data.terminal == "kitty" and .data.command[0] == "kitty" and .data.command[1] == "bxcachy"' >/dev/null || fail 'kitty takes the command directly'
rm "$tmp/cfg/xdg-terminals.list"; rm "$tmp/bin/kitty"
ai launch --dry-run --json | jq -e '.data.terminal == "ghostty"' >/dev/null || fail 'without a list, the first installed terminal is used'
rm "$tmp/cfg/bxcachy/ai.json"
[[ "$(code "$binary" ai launch)" == 4 ]] || fail 'no default and no id exits 4'
echo "ai-test: ok"

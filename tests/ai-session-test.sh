#!/usr/bin/env bash
# `bxrig ai session` and `bxrig ai models` with fake tmux, ollama, systemctl and sudo. Usage: ai-session-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/cfg/bxrig" "$tmp/tm" "$tmp/work"
export LOG="$tmp/log"; : > "$LOG"
cat > "$tmp/bin/tmux" <<'SH'
#!/usr/bin/env bash
echo "tmux $*" >> "$LOG"
case "$1" in
  new-session) while [[ $# -gt 0 ]]; do [[ "$1" == -s ]] && n="$2"; shift; done; : > "$TM/$n" ;;
  list-sessions) ls "$TM" 2>/dev/null | grep . || exit 1 ;;
  attach-session) echo "attached $3" ;;
  kill-session) rm -f "$TM/$3" ;;
esac
SH
printf '#!/usr/bin/env bash\necho claude\n' > "$tmp/bin/claude"
cat > "$tmp/bin/ollama" <<'SH'
#!/usr/bin/env bash
echo "ollama $*" >> "$LOG"
case "$1" in
  list) printf 'NAME ID SIZE\nqwen3:8b abc 5GB\n' ;;
  ps) printf 'NAME ID\n' ;;
  pull) echo "pulling $2"; [[ -n "${NO_SERVER:-}" ]] && { echo "could not connect" >&2; exit 1; } ;;
  rm) echo "deleted '$2'" ;;
esac
SH
printf '#!/usr/bin/env bash\necho "systemctl $*" >> "$LOG"\n[[ "$1" == is-active ]] && echo "${SVC:-inactive}"\nexit 0\n' > "$tmp/bin/systemctl"
printf '#!/usr/bin/env bash\necho "sudo $*" >> "$LOG"\nexec "$@"\n' > "$tmp/bin/sudo"
chmod +x "$tmp/bin"/*
run() { env -u ANTHROPIC_API_KEY HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_DATA_HOME="$tmp/data" BXRIG_SELF=bxrig TM="$tmp/tm" LOG="$LOG" SVC="${SVC:-}" NO_SERVER="${NO_SERVER:-}" PWD="$tmp/work" PATH="$tmp/bin:$PATH" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
printf '{"default":"claude-code"}\n' > "$tmp/cfg/bxrig/ai.json"; printf '{"backend":"file"}\n' > "$tmp/cfg/bxrig/secrets.json"

# ---- sessions ----
run "$binary" ai session list | grep -q 'No agent sessions are running' || fail 'empty list'
run "$binary" ai session start --dry-run --json | jq -e ".data.session == \"bxrig-claude-code\" and .data.dir == \"$tmp/work\" and .data.command[0:6] == [\"tmux\",\"new-session\",\"-d\",\"-s\",\"bxrig-claude-code\",\"-c\"]" >/dev/null || fail "dry-run: $(run "$binary" ai session start --dry-run --json)"
[[ ! -s "$LOG" || "$(grep -vc 'list-sessions' "$LOG")" == 0 ]] || fail 'dry-run created a session'
run "$binary" ai session start | grep -q 'Started bxrig-claude-code' || fail 'start'
grep -q "tmux new-session -d -s bxrig-claude-code -c $tmp/work 'bxrig' 'secrets' 'run' 'ANTHROPIC_API_KEY' '--' 'claude'" "$LOG" || fail "tmux command: $(grep new-session "$LOG")"
run "$binary" ai session start | grep -q 'already running' || fail 'start is idempotent'
[[ "$(grep -c new-session "$LOG")" == 1 ]] || fail 'a second session was created'
run "$binary" ai session start claude-code --name=api --dir="$tmp" --json | jq -e '.data.session == "bxrig-claude-code-api" and .data.dir == "'"$tmp"'"' >/dev/null || fail 'named session in another folder'
run "$binary" ai session list --json | jq -e '.data.sessions == ["bxrig-claude-code","bxrig-claude-code-api"]' >/dev/null || fail 'list'
touch "$tmp/tm/other-session"; run "$binary" ai session list --json | jq -e '(.data.sessions | index("other-session")) == null' >/dev/null || fail "other tmux sessions are not listed"
run "$binary" ai session attach claude-code-api | grep -q 'attached bxrig-claude-code-api' || fail 'attach by short name'
[[ "$(code "$binary" ai session attach nope)" == 4 ]] || fail 'attach to a missing session exits 4'
[[ "$(code "$binary" ai session start --name='a b')" == 4 ]] || fail 'a bad name exits 4'
[[ "$(code "$binary" ai session start codex-cli)" == 4 ]] || fail 'an agent that is not installed exits 4'
[[ "$(code "$binary" ai session stop claude-code-api)" == 2 ]] || fail 'stop without --yes exits 2'
[[ -e "$tmp/tm/bxrig-claude-code-api" ]] || fail 'the plan ended the session'
run "$binary" ai session stop claude-code-api --yes | grep -q 'was ended' || fail 'stop --yes'
[[ ! -e "$tmp/tm/bxrig-claude-code-api" ]] || fail 'stop did not end it'
mkdir -p "$tmp/nobin"; ln -sf "$(command -v sh)" "$tmp/nobin/sh"; ln -sf "$tmp/bin/claude" "$tmp/nobin/claude"
set +e; env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" PATH="$tmp/nobin" "$binary" ai session start >/dev/null 2>&1; rc=$?; set -e; [[ "$rc" == 4 ]] || fail "no tmux exits 4 (got $rc)"

# ---- models ----
run "$binary" ai models list | grep -q 'qwen3:8b' || fail 'models list'
run "$binary" ai models ps --json | jq -e '.data.output | startswith("NAME")' >/dev/null || fail 'models ps --json'
: > "$LOG"; run "$binary" ai models pull qwen3:8b | grep -q 'pulling qwen3:8b' || fail 'pull shows progress'
grep -q '^ollama pull qwen3:8b$' "$LOG" || fail 'pull command'
[[ "$(code "$binary" ai models pull 'a;rm -rf')" == 4 ]] || fail 'a bad model name exits 4'
[[ "$(NO_SERVER=1 code "$binary" ai models pull qwen3:8b)" == 1 ]] || fail "pull returns ollama's exit code"
[[ "$(code "$binary" ai models rm qwen3:8b)" == 2 ]] || fail 'rm without --yes exits 2'
run "$binary" ai models rm qwen3:8b --yes | grep -q "deleted" || fail 'rm --yes'
run "$binary" ai models status --json | jq -e '.data.installed == true and .data.service_active == false' >/dev/null || fail 'status inactive'
SVC=active run "$binary" ai models status --json | jq -e '.data.service_active == true' >/dev/null || fail 'status active'
: > "$LOG"; [[ "$(code "$binary" ai models enable)" == 2 ]] || fail 'enable without --yes exits 2'
[[ ! -s "$LOG" ]] || fail 'the enable plan ran something'
run "$binary" ai models enable --yes | grep -q 'enabled and running' || fail 'enable --yes'
grep -q 'sudo systemctl enable --now ollama' "$LOG" || fail 'enable command'
mv "$tmp/bin/ollama" "$tmp/ollama.off"; [[ "$(code "$binary" ai models list)" == 4 ]] || fail 'no ollama exits 4'
echo "ai-session-test: ok"

#!/usr/bin/env bash
# `bxcachy status` and the system-aware wizard flags, with a fake pacman. Usage: status-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home"
printf '#!/usr/bin/env bash\nprintf "git\\ncurl\\nhyprland\\nghostty\\nollama\\nclaude-code\\n"\n' > "$tmp/bin/pacman"; chmod +x "$tmp/bin/pacman"
run() { env HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_ROOT_FS=ext4 SHELL=/usr/bin/zsh PATH="$tmp/bin:$PATH" "$@"; }

# status: detected answers and the missing default apps
run "$binary" status --json | jq -e '.data.detected | map(.id) | (index("terminal") != null)' >/dev/null || fail "status json: $(run "$binary" status --json)"
run "$binary" status --json | jq -e '.data.default_apps_missing | (index("timeshift") != null) and (index("btrfs-assistant") == null)' >/dev/null || fail 'status missing apps (timeshift yes, btrfs-assistant not on ext4)'
run "$binary" status | grep -q 'Default apps not installed:' || fail 'status text'

# init --from-system --print-answers: what the machine has, as wizard answers
run "$binary" init --from-system --print-answers --json | jq -e '.data.answers.terminal == "ghostty" and (.data.answers.ai_agents | index("claude-code") != null)' >/dev/null || fail "from-system: $(run "$binary" init --from-system --print-answers --json)"
echo "status-test ok"

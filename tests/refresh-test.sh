#!/usr/bin/env bash
# `bxrig refresh ...` with a fake bxrig (logs the commands it is asked to run), a fake terminal and a temp home. Usage: refresh-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home"; export LOG="$tmp/log"; : > "$LOG"
printf '#!/usr/bin/env bash\necho "self $*" >> "$LOG"\n' > "$tmp/self"
printf '#!/usr/bin/env bash\n:\n' > "$tmp/bin/ghostty"
printf '#!/usr/bin/env bash\necho "noctalia $*" >> "$LOG"\n' > "$tmp/bin/noctalia"
printf '#!/usr/bin/env bash\nif [[ "$1" == -u ]]; then echo 1000; else /usr/bin/id "$@"; fi\n' > "$tmp/bin/id"
chmod +x "$tmp/self" "$tmp/bin"/*
run() { env HOME="$tmp/home" SHELL=/usr/bin/zsh BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_STATE_HOME="$tmp/state" BXRIG_SELF="$tmp/self" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
has() { grep -qF -- "$1" "$LOG"; }

run "$binary" refresh list --json | jq -e '.data.components | map(.id) == ["hyprland","noctalia","terminals","shell","nvim","theme"]' >/dev/null || fail 'list'
[[ "$(code "$binary" refresh bogus)" == 2 && "$(code "$binary" refresh)" == 2 ]] || fail 'bad usage exits 2'

# ---- terminals: a plan, then the files; a second run changes nothing ----
[[ "$(code "$binary" refresh terminals)" == 2 ]] || fail 'without --yes it is a plan'
[[ ! -e "$tmp/cfg/ghostty/config" ]] || fail 'the plan wrote a file'
run "$binary" refresh terminals --dry-run --json | jq -e '.dry_run and (.data.units | map(select(.name == "terminal-ghostty" and .state == "missing" and .result == "written")) | length == 1)' >/dev/null || fail "dry run plan: $(run "$binary" refresh terminals --dry-run)"
run "$binary" refresh terminals --yes >/dev/null; grep -q 'font-family' "$tmp/cfg/ghostty/config" || fail 'the ghostty starter was written'
[[ ! -e "$tmp/cfg/kitty/kitty.conf" ]] || fail 'a terminal that is not installed got a config'
! run "$binary" refresh terminals --yes | grep -q 'refreshed: terminal-ghostty' || fail 'a second run rewrote a clean file'

# ---- your edits are kept unless --force, and --force takes a backup ----
echo '# mine' >> "$tmp/cfg/ghostty/config"
run "$binary" refresh terminals --dry-run | grep -q 'kept: you edited it' || fail 'the plan says an edited file is kept'
run "$binary" refresh terminals --yes | grep -q 'kept (you edited it): terminal-ghostty' || fail 'an edited file is reported as kept'
grep -q '^# mine' "$tmp/cfg/ghostty/config" || fail 'an edited file was overwritten without --force'
run "$binary" refresh terminals --yes --force >/dev/null
! grep -q '^# mine' "$tmp/cfg/ghostty/config" || fail '--force did not overwrite'
find "$tmp/state" -name '*.bak' | grep -q . || fail "--force took no backup: $(find "$tmp/state" -type f | head -3)"

# ---- shell ----
run "$binary" refresh shell --yes >/dev/null
[[ -s "$tmp/cfg/starship.toml" ]] && grep -q 'bxrig shell' "$tmp/home/.zshrc" || fail 'shell files'
echo '# my prompt' >> "$tmp/cfg/starship.toml"
run "$binary" refresh shell --yes | grep -q 'kept (you edited it): starship' || fail 'an edited starship.toml is kept'
grep -q '^# my prompt' "$tmp/cfg/starship.toml" || fail 'starship.toml was overwritten'

# ---- the components that run commands ----
: > "$LOG"; run "$binary" refresh hyprland --yes >/dev/null
has 'self keys apply --yes' && has 'self appearance apply' && has 'self display apply' || fail "hyprland: $(cat "$LOG")"
[[ ! -e "$tmp/cfg/hypr/hyprland.lua" ]] || fail 'the starter is not written without --starter'
run "$binary" refresh hyprland --starter --yes >/dev/null; [[ -s "$tmp/cfg/hypr/hyprland.lua" ]] || fail '--starter writes the starter'
echo '-- my config' >> "$tmp/cfg/hypr/hyprland.lua"
run "$binary" refresh hyprland --starter --yes | grep -q 'kept (you edited it): hyprland' || fail 'an edited hyprland.lua is kept'
grep -q '^-- my config' "$tmp/cfg/hypr/hyprland.lua" || fail 'hyprland.lua was overwritten'
: > "$LOG"; run "$binary" refresh noctalia --yes >/dev/null; has 'self theme set' && has 'self appearance apply' && has 'noctalia msg config-reload' || fail "noctalia: $(cat "$LOG")"
: > "$LOG"; run "$binary" refresh nvim --yes >/dev/null; has 'self editor refresh --yes' || fail 'nvim'
: > "$LOG"; run "$binary" refresh theme --yes >/dev/null; has 'self theme set' || fail 'theme'
: > "$LOG"; run "$binary" refresh all --yes >/dev/null; has 'self editor refresh' && has 'self keys apply' && has 'self theme set' || fail 'all'
: > "$LOG"; run "$binary" refresh all --dry-run >/dev/null; [[ ! -s "$LOG" ]] || fail 'a dry run ran a command'

# ---- reinstall is init --rerun ----
{ run "$binary" reinstall --dry-run 2>&1 || true; } | head -3 | grep -qiE 'rerun|plan|wizard|answers|needs a terminal|terminal' || fail 'reinstall reaches init'
echo "refresh-test: ok"

#!/usr/bin/env bash
# `bxcachy init`: answers file in, ordinary commands out (a fake bxcachy and git record them), plus the wizard in a pty. Usage: init-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home"
export LOG="$tmp/log"; : > "$LOG"
# the fake "bxcachy": records its arguments, fails on `setup shell` when FAIL_SHELL is set
cat > "$tmp/self" <<'FAKE'
#!/usr/bin/env bash
echo "bxcachy $*" >> "$LOG"
[[ -n "${FAIL_SHELL:-}" && "$1 $2" == "setup shell" ]] && { echo "boom"; exit 3; }
[[ -n "${FAIL_KEY:-}" && "$1 $2" == "secrets set" ]] && exit 4
echo "ok $1 $2"
FAKE
printf '#!/usr/bin/env bash\necho "git $*" >> "$LOG"\n' > "$tmp/bin/git"
chmod +x "$tmp/self" "$tmp/bin/git"
run() { env BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_STATE_HOME="$tmp/state" BXCACHY_SELF="$tmp/self" HOME="$tmp/home" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
cat > "$tmp/a.json" <<'JSON'
{"desktops":"both","login_session":"plasma","layout":"scrolling","terminal":"ghostty","terminals_extra":["kitty"],"shell":"zsh","mac_keys":true,
 "ai_orchestrators":["pane"],"git_name":"Ada Lovelace","git_email":"ada@example.com","vpn":"tailscale","databases":["postgres"],"ssh_key":true,"toolchains":["python"]}
JSON

# no --yes: the plan, exit 2, nothing run
[[ "$(code "$binary" init --answers="$tmp/a.json")" == 2 ]] || fail 'no --yes exits 2'
[[ ! -s "$LOG" ]] || fail 'the plan ran something'
run "$binary" init --answers="$tmp/a.json" --dry-run --json | jq -e '.ok and (.data.steps | map(.id) == ["hyprland","plasma","terminal","shell","xremap","toolchain-python","apps","default-terminal","db-postgres","git-name","git-email","ssh-key","session"]) and (.data.pending == [])' >/dev/null || fail 'dry-run --json plan'
[[ ! -s "$LOG" ]] || fail 'dry-run ran something'

# --yes: every step runs in order; our own commands get --yes, git does not
run "$binary" init --answers="$tmp/a.json" --yes --json | jq -e '.ok and (.data.done | length == 13) and (.data.failed | length == 0)' >/dev/null || fail 'init --yes --json'
expected='bxcachy setup hyprland --terminal=ghostty --layout=scrolling --yes
bxcachy setup plasma --yes
bxcachy setup terminal --default=ghostty --also=kitty --yes
bxcachy setup shell --shell=zsh --yes
bxcachy setup xremap --build=hypr --yes
bxcachy profile-install python --yes
bxcachy install pane tailscale --yes
bxcachy default terminal ghostty --yes
bxcachy db start postgres --yes
git config --global user.name Ada Lovelace
git config --global user.email ada@example.com
bxcachy ssh key --email=ada@example.com --yes
bxcachy session set plasma --yes'
[[ "$(cat "$LOG")" == "$expected" ]] || fail "commands run were: $(cat "$LOG")"

# a failing step stops the rest: exit 7 (some done), the others skipped
: > "$LOG"
rc=0; FAIL_SHELL=1 run "$binary" init --answers="$tmp/a.json" --yes --json > "$tmp/out.json" || rc=$?
[[ "$rc" == 7 ]] || fail "exit was $rc, wanted 7"
jq -e '(.data.done | map(.id) == ["hyprland","plasma","terminal"]) and (.data.failed[0].id == "shell") and (.data.skipped | length == 9)' "$tmp/out.json" >/dev/null || fail "failure report: $(cat "$tmp/out.json")"
! grep -q 'session set' "$LOG" || fail 'a step ran after the failure'

# bad input
[[ "$(code "$binary" init --answers="$tmp/missing.json")" == 4 ]] || fail 'a missing answers file exits 4'
echo '{' > "$tmp/bad.json"; [[ "$(code "$binary" init --answers="$tmp/bad.json")" == 4 ]] || fail 'a broken answers file exits 4'
echo '{"desktops":"gnome"}' > "$tmp/gnome.json"; [[ "$(code "$binary" init --answers="$tmp/gnome.json" --yes)" == 4 ]] || fail 'an unknown desktop exits 4'
[[ "$(code "$binary" init extra)" == 2 ]] || fail 'stray arguments exit 2'
[[ "$(run "$binary" init --print-answers)" == '{}' ]] || fail 'no saved answers prints {}'
rc=0; run "$binary" init </dev/null >/dev/null 2>&1 || rc=$?; [[ "$rc" == 4 ]] || fail "no terminal should exit 4, got $rc"

# an optional step (typing an API key) that cannot run is reported and the plan goes on
: > "$LOG"
cat > "$tmp/ai.json" <<'JSON'
{"ai_agents":["claude-code","codex-cli"],"ai_default":"claude-code","ai_keys":"now","ai_global_keys":["ANTHROPIC_API_KEY"],"git_name":"Ada"}
JSON
FAIL_KEY=1 run "$binary" init --answers="$tmp/ai.json" --yes > "$tmp/ai.out" 2>&1 || fail "a skipped key must not fail the run: $(cat "$tmp/ai.out")"
grep -q 'Skipped: key-ANTHROPIC_API_KEY (could not run' "$tmp/ai.out" || fail "the skipped key is reported: $(cat "$tmp/ai.out")"
grep -q 'bxcachy ai default claude-code' "$LOG" && grep -q 'git config --global user.name Ada' "$LOG" || fail "steps after a skipped key still run: $(cat "$LOG")"
grep -q 'bxcachy secrets setup' "$LOG" || fail 'the keyring check runs'

# the wizard in a pty: Enter on the welcome screen, Tab through the pages to the review, Enter. The answers are saved (mode 600).
: > "$LOG"
python3 - "$binary" "$tmp" <<'PY'
import os, pty, select, sys, time, struct, fcntl, termios
binary, tmp = sys.argv[1:3]
env = dict(os.environ, BXCACHY_CONFIG_HOME=tmp + '/cfg', BXCACHY_STATE_HOME=tmp + '/state', BXCACHY_SELF=tmp + '/self', HOME=tmp + '/home', PATH=tmp + '/bin:' + os.environ['PATH'], LOG=tmp + '/log')
pid, fd = pty.fork()
if pid == 0:
    os.execve(binary, [binary, 'init', '--dry-run'], env)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', 36, 120, 0, 0))
def pump(t):
    end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try:
                if not os.read(fd, 65536): return
            except OSError: return
pump(1.5)
for k in [b'\r'] + [b'\t'] * 10 + [b'\r']:
    os.write(fd, k); pump(0.3)
pump(1.5)
_, status = os.waitpid(pid, 0)
sys.exit(os.WEXITSTATUS(status) if os.WIFEXITED(status) else 1)
PY
[[ -f "$tmp/cfg/bxcachy/answers.json" ]] || fail 'the wizard did not save the answers'
[[ "$(stat -c %a "$tmp/cfg/bxcachy/answers.json")" == 600 ]] || fail 'answers.json must be mode 600'
run "$binary" init --print-answers | jq -e '.desktops == "hyprland" and .shell == "zsh" and .terminal == "ghostty" and (has("login_session") | not)' >/dev/null || fail "saved answers: $(run "$binary" init --print-answers)"
[[ ! -s "$LOG" ]] || fail '--dry-run ran commands'
echo "init tests passed"

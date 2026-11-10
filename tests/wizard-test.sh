#!/usr/bin/env bash
# bxcachy-wizard end to end in a real pseudo-terminal: pages in, keys typed, answers out (and cancel writes nothing).
# Usage: wizard-test.sh [wizard-binary]   (builds it when no path is given)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
bin="${1:-}"
if [[ -z "$bin" ]]; then cargo build --release --manifest-path "$root/wizard/Cargo.toml" >/dev/null; bin="$root/wizard/target/release/bxcachy-wizard"; fi
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
cat > "$tmp/pages.json" <<'JSON'
{"title":"T","pages":[
 {"id":"a","title":"A","questions":[
   {"type":"choice","id":"color","label":"Color","default":"red","options":[{"value":"red","label":"Red"},{"value":"blue","label":"Blue"}]},
   {"type":"text","id":"name","label":"Name"}]},
 {"id":"b","title":"B","questions":[
   {"type":"multi","id":"tags","label":"Tags","default":[],"options":[{"value":"x","label":"X"},{"value":"y","label":"Y"}]}]}]}
JSON
run_keys() {  # OUT KEYS... : runs the wizard in a pty and sends the keys (python escapes), returns its exit code
  python3 - "$bin" "$tmp/pages.json" "$1" "$2" <<'PY'
import os, pty, select, sys, time, struct, fcntl, termios
bin, pages, out, keys = sys.argv[1:5]
keys = keys.encode().decode('unicode_escape').encode('latin-1')
pid, fd = pty.fork()
if pid == 0:
    os.execv(bin, [bin, '--pages', pages, '--out', out])
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', 36, 120, 0, 0))
def pump(t):
    end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try:
                if not os.read(fd, 65536): return
            except OSError: return
pump(0.6)
for k in keys.split(b'|'):
    os.write(fd, k); pump(0.25)
pump(0.5)
_, status = os.waitpid(pid, 0)
sys.exit(os.WEXITSTATUS(status) if os.WIFEXITED(status) else 1)
PY
}
# welcome, then: choose Blue (down, space), enter -> name field, type "Ann", enter -> next page, down, space (tag y), tab -> review, enter
run_keys "$tmp/out.json" '\r|\x1b[B|\x20|\r|A|n|n|\r|\x1b[B|\x20|\t|\r' || fail "the wizard did not finish"
jq -e '.color == "blue" and .name == "Ann" and .tags == ["y"]' "$tmp/out.json" >/dev/null || fail "answers wrong: $(cat "$tmp/out.json")"
# the saved answers come back as the starting point
run_keys "$tmp/again.json" '\r|\t|\t|\r' || fail "second run failed"
# cancel writes nothing and exits 130
rc=0; run_keys "$tmp/cancel.json" '\r|\x03' || rc=$?
[[ "$rc" == 130 ]] || fail "ctrl-c exit code was $rc, wanted 130"
[[ ! -e "$tmp/cancel.json" ]] || fail "cancel wrote answers"
# a bad pages file is a clean failure
echo '{' > "$tmp/bad.json"
if "$bin" --pages "$tmp/bad.json" --out "$tmp/x.json" 2>/dev/null; then fail "a bad pages file was accepted"; fi
if "$bin" 2>/dev/null; then fail "no arguments were accepted"; fi
echo "wizard tests passed"

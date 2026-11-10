#!/usr/bin/env bash
# `bxcachy toolchain node`: the pinned nvm installer (a fake curl serves a fake one) and Node.js through nvm. Usage: toolchain-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home"
export LOG="$tmp/log"; : > "$LOG"
printf '#!/usr/bin/env bash\nif [[ "$1" == -u ]]; then echo "${MOCK_UID:-1000}"; else /usr/bin/id "$@"; fi\n' > "$tmp/bin/id"
# fake curl: records the URL and writes a fake nvm installer to the -o path
cat > "$tmp/bin/curl" <<'MOCK'
#!/usr/bin/env bash
[[ "$1" == --version ]] && { echo "curl 8.0"; exit 0; }
out=""; url=""
while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2 ;; -*) shift ;; *) url="$1"; shift ;; esac; done
echo "curl $url" >> "$LOG"
cat > "$out" <<'INSTALLER'
mkdir -p "$NVM_DIR"
cat > "$NVM_DIR/nvm.sh" <<"M"
nvm() {
  case "$1" in
    --version) echo 0.41.0 ;;
    install) echo "nvm install $2" >> "$LOG"; mkdir -p "$NVM_DIR/bin"; printf '#!/usr/bin/env bash\necho v22.11.0\n' > "$NVM_DIR/bin/node"; chmod +x "$NVM_DIR/bin/node" ;;
    alias) echo "nvm alias $2 $3" >> "$LOG" ;;
  esac
}
[ -x "$NVM_DIR/bin/node" ] && export PATH="$NVM_DIR/bin:$PATH"
true
M
echo "installer ran" >> "$LOG"
INSTALLER
MOCK
chmod +x "$tmp/bin/"*
run() { env HOME="$tmp/home" NVM_DIR="$tmp/home/.nvm" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

[[ "$(code "$binary" toolchain)" == 2 && "$(code "$binary" toolchain python)" == 2 ]] || fail 'usage exits 2'
[[ "$(code "$binary" toolchain node)" == 2 ]] || fail 'no --yes exits 2'
[[ ! -s "$LOG" && ! -e "$tmp/home/.nvm" ]] || fail 'the plan changed something'
pin="$(jq -r .toolchain.nvm.installer "$root/box.json")"
run "$binary" toolchain node --dry-run --json | jq -e --arg u "$pin" '.ok and (.data.steps | map(.id) == ["nvm","node"]) and (.data.steps[0].title | contains($u))' >/dev/null || fail 'the plan names nvm and Node, and the pinned installer from box.json'
[[ "$(MOCK_UID=0 code "$binary" toolchain node --yes)" == 4 ]] || fail 'root exits 4'

run "$binary" toolchain node --yes --json | jq -e '.ok and (.data.done | map(.id) == ["nvm","node"])' >/dev/null || fail 'toolchain node --yes'
[[ "$(sed -n 1p "$LOG")" == "curl $pin" ]] || fail "downloaded: $(sed -n 1p "$LOG")"
grep -q 'installer ran' "$LOG" && grep -q 'nvm install lts/\*' "$LOG" && grep -q 'nvm alias default lts/\*' "$LOG" || fail "nvm and Node were not installed: $(cat "$LOG")"
[[ -x "$tmp/home/.nvm/bin/node" ]] || fail 'node is not there'

# again: everything is in place, nothing runs
: > "$LOG"
run "$binary" toolchain node --yes --json | jq -e '.ok and (.data.steps | length == 0)' >/dev/null || fail 're-run should have no steps'
[[ ! -s "$LOG" ]] || fail 're-run ran something'
echo "toolchain tests passed"

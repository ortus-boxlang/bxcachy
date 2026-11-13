#!/usr/bin/env bash
# bootstrap/web-install.sh (the published one-line installer) with a fake download server and fake stages. Usage: web-install-test.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/bootstrap/web-install.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/srv/stable" "$tmp/srv/beta" "$tmp/bundle/bootstrap" "$tmp/binhome"; export LOG="$tmp/log"; : > "$LOG"
bash -n "$script" || fail 'syntax'
# fake tools
printf '#!/usr/bin/env bash\nout=""; url=""\nwhile [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift ;; http://*) url="$1" ;; esac; shift; done\nsrc="%s/srv/${url#http://fake/}"\n[ -f "$src" ] || exit 22\ncp "$src" "$out"\n' "$tmp" > "$tmp/bin/curl"
printf '#!/usr/bin/env bash\n' > "$tmp/bin/pacman"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/bin/sudo"
chmod +x "$tmp/bin"/*
# the bundle: a bootstrap/install.sh that logs its stage and installs the binary like the real binary stage
cat > "$tmp/bundle/bootstrap/install.sh" <<'INS'
#!/usr/bin/env bash
echo "stage $*" >> "$LOG"
if [[ "$1" == binary ]]; then
  while [[ $# -gt 0 ]]; do [[ "$1" == --binary ]] && { mkdir -p "$BXCACHY_BIN_DIR"; cp "$2" "$BXCACHY_BIN_DIR/bxcachy"; chmod +x "$BXCACHY_BIN_DIR/bxcachy"; }; shift; done
fi
INS
chmod +x "$tmp/bundle/bootstrap/install.sh"
tar -czf "$tmp/srv/stable/bootstrap.tar.gz" -C "$tmp/bundle" bootstrap
printf '#!/usr/bin/env bash\necho "bxcachy $*" >> "$LOG"\n' > "$tmp/srv/stable/bxcachy-linux-x86_64"
for f in bxcachy-linux-x86_64 bootstrap.tar.gz; do echo "$(sha256sum "$tmp/srv/stable/$f" | cut -d' ' -f1)  $f" > "$tmp/srv/stable/$f.sha256"; done
printf 'version=0.12.0\ncommit=abc\nsha256=x\nbuiltAt=now\n' > "$tmp/srv/stable/version-latest.properties"
cp -r "$tmp/srv/stable/." "$tmp/srv/beta/"
run() { env HOME="$tmp/home" BXCACHY_BIN_DIR="$tmp/binhome" BXCACHY_BASE_URL=http://fake BXCACHY_INSTALL_ALLOW_ROOT=1 PATH="$tmp/bin:$PATH" LOG="$LOG" NO_COLOR=1 bash "$script" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

# the banner, the wordmark and the tagline; a dry run downloads nothing
out="$(run --dry-run --yes 2>&1)"
[[ "$out" == *'███████▄'* && "$out" == *'Your developer machine, set up in minutes.'* && "$out" == *'Powered by BoxLang'* ]] || fail 'banner'
[[ ! -s "$LOG" ]] || fail 'a dry run did something'
# bad arguments
[[ "$(code --channel nightly)" == 1 ]] || fail 'a bad channel is refused'
[[ "$(code --answers "$tmp/nope.json")" == 1 ]] || fail 'a missing answers file is refused'
[[ "$(code --bogus)" == 1 ]] || fail 'an unknown option is refused'
# no human input: stages in order, then the wizard with the default answers
out="$(run --yes 2>&1)" || fail "install: $out"
[[ "$(grep -c '^stage' "$LOG")" == 4 ]] || fail "four stages: $(cat "$LOG")"
[[ "$(grep '^stage' "$LOG" | cut -d' ' -f2 | tr '\n' ' ')" == "packages toolchains binary core " ]] || fail "stage order: $(cat "$LOG")"
grep -q '^bxcachy init --defaults --yes' "$LOG" || fail "the wizard runs with defaults: $(cat "$LOG")"
[[ -x "$tmp/binhome/bxcachy" ]] || fail 'the binary was installed'
# answers file
: > "$LOG"; echo '{"desktops":"hyprland"}' > "$tmp/answers.json"; run --yes --answers "$tmp/answers.json" >/dev/null 2>&1
grep -q "^bxcachy init --answers $tmp/answers.json --yes" "$LOG" || fail 'the wizard runs with your answers'
# no wizard
: > "$LOG"; run --yes --no-wizard >/dev/null 2>&1; ! grep -q '^bxcachy init' "$LOG" || fail '--no-wizard'
# the beta channel downloads from beta/
echo "beta-build" >> "$tmp/srv/beta/bxcachy-linux-x86_64"; echo "$(sha256sum "$tmp/srv/beta/bxcachy-linux-x86_64" | cut -d' ' -f1)  bxcachy-linux-x86_64" > "$tmp/srv/beta/bxcachy-linux-x86_64.sha256"
: > "$LOG"; run --yes --channel beta --no-wizard >/dev/null 2>&1; grep -q beta-build "$tmp/binhome/bxcachy" || fail 'the beta binary'
# a tampered download stops before any stage
echo "deadbeef  bxcachy-linux-x86_64" > "$tmp/srv/stable/bxcachy-linux-x86_64.sha256"
: > "$LOG"; [[ "$(code --yes)" == 1 ]] || fail 'a checksum mismatch fails'
! grep -q '^stage' "$LOG" || fail 'a stage ran after a checksum mismatch'
# root is refused
rc=0; env HOME="$tmp/home" BXCACHY_BASE_URL=http://fake PATH="$tmp/bin:$PATH" NO_COLOR=1 bash "$script" --yes >/dev/null 2>&1 || rc=$?
[[ "$(id -u)" != 0 || "$rc" == 1 ]] || fail 'root is refused'
echo "web-install-test ok"

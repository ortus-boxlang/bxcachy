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
  while [[ $# -gt 0 ]]; do [[ "$1" == --binary ]] && { mkdir -p "$BXRIG_BIN_DIR"; cp "$2" "$BXRIG_BIN_DIR/bxrig"; chmod +x "$BXRIG_BIN_DIR/bxrig"; }; shift; done
fi
INS
chmod +x "$tmp/bundle/bootstrap/install.sh"
tar -czf "$tmp/srv/stable/bootstrap.tar.gz" -C "$tmp/bundle" bootstrap
printf '#!/usr/bin/env bash\necho "bxrig $*" >> "$LOG"\n' > "$tmp/srv/stable/bxrig-linux-x86_64"
for f in bxrig-linux-x86_64 bootstrap.tar.gz; do echo "$(sha256sum "$tmp/srv/stable/$f" | cut -d' ' -f1)  $f" > "$tmp/srv/stable/$f.sha256"; done
printf 'version=0.12.0\ncommit=abc\nsha256=x\nbuiltAt=now\n' > "$tmp/srv/stable/version-latest.properties"
cp -r "$tmp/srv/stable/." "$tmp/srv/beta/"
run() { env HOME="$tmp/home" BXRIG_BIN_DIR="$tmp/binhome" BXRIG_BASE_URL=http://fake BXRIG_INSTALL_ALLOW_ROOT=1 PATH="$tmp/bin:$PATH" LOG="$LOG" NO_COLOR=1 bash "$script" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

# the banner, the wordmark and the tagline; a dry run downloads nothing
out="$(run --dry-run --yes 2>&1)"
[[ "$out" == *'██╔══██╗ ██╗  ██╗'* && "$out" == *'Your dev rig. Beautiful by default.'* && "$out" == *'Powered by BoxLang'* ]] || fail 'banner'
[[ ! -s "$LOG" ]] || fail 'a dry run did something'
# bad arguments
[[ "$(code --channel nightly)" == 1 ]] || fail 'a bad channel is refused'
[[ "$(code --answers "$tmp/nope.json")" == 1 ]] || fail 'a missing answers file is refused'
[[ "$(code --bogus)" == 1 ]] || fail 'an unknown option is refused'
# no human input: stages in order, then the wizard with the default answers
out="$(run --yes 2>&1)" || fail "install: $out"
[[ "$(grep -c '^stage' "$LOG")" == 4 ]] || fail "four stages: $(cat "$LOG")"
[[ "$(grep '^stage' "$LOG" | cut -d' ' -f2 | tr '\n' ' ')" == "packages toolchains binary core " ]] || fail "stage order: $(cat "$LOG")"
grep -q '^bxrig init --defaults --yes' "$LOG" || fail "the wizard runs with defaults: $(cat "$LOG")"
[[ -x "$tmp/binhome/bxrig" ]] || fail 'the binary was installed'
# answers file
: > "$LOG"; echo '{"desktops":"hyprland"}' > "$tmp/answers.json"; run --yes --answers "$tmp/answers.json" >/dev/null 2>&1
grep -q "^bxrig init --answers $tmp/answers.json --yes" "$LOG" || fail 'the wizard runs with your answers'
# no wizard
: > "$LOG"; run --yes --no-wizard >/dev/null 2>&1; ! grep -q '^bxrig init' "$LOG" || fail '--no-wizard'
# the beta channel downloads from beta/
echo "beta-build" >> "$tmp/srv/beta/bxrig-linux-x86_64"; echo "$(sha256sum "$tmp/srv/beta/bxrig-linux-x86_64" | cut -d' ' -f1)  bxrig-linux-x86_64" > "$tmp/srv/beta/bxrig-linux-x86_64.sha256"
: > "$LOG"; run --yes --channel beta --no-wizard >/dev/null 2>&1; grep -q beta-build "$tmp/binhome/bxrig" || fail 'the beta binary'
# a tampered download stops before any stage
echo "deadbeef  bxrig-linux-x86_64" > "$tmp/srv/stable/bxrig-linux-x86_64.sha256"
: > "$LOG"; [[ "$(code --yes)" == 1 ]] || fail 'a checksum mismatch fails'
! grep -q '^stage' "$LOG" || fail 'a stage ran after a checksum mismatch'
# signed releases: with a public key the release information must verify, and both files must match it
if command -v openssl >/dev/null; then
  openssl genpkey -algorithm ed25519 -out "$tmp/k.pem" 2>/dev/null; openssl pkey -in "$tmp/k.pem" -pubout -out "$tmp/pub.pem"
  openssl genpkey -algorithm ed25519 -out "$tmp/o.pem" 2>/dev/null; openssl pkey -in "$tmp/o.pem" -pubout -out "$tmp/o.pub"
  echo "$(sha256sum "$tmp/srv/stable/bxrig-linux-x86_64" | cut -d' ' -f1)" > /dev/null
  echo "good build" > "$tmp/srv/stable/bxrig-linux-x86_64"; echo "$(sha256sum "$tmp/srv/stable/bxrig-linux-x86_64" | cut -d' ' -f1)  bxrig-linux-x86_64" > "$tmp/srv/stable/bxrig-linux-x86_64.sha256"
  bsha="$(cut -d' ' -f1 "$tmp/srv/stable/bootstrap.tar.gz.sha256")"; asha="$(cut -d' ' -f1 "$tmp/srv/stable/bxrig-linux-x86_64.sha256")"
  printf 'version=0.12.0\ncommit=abc\nsha256=%s\nbootstrap_sha256=%s\n' "$asha" "$bsha" > "$tmp/srv/stable/version-latest.properties"
  sign() { openssl pkeyutl -sign -rawin -inkey "$tmp/k.pem" -in "$tmp/srv/stable/version-latest.properties" -out "$tmp/srv/stable/version-latest.properties.sig"; }
  prun() { env HOME="$tmp/home" BXRIG_BIN_DIR="$tmp/binhome" BXRIG_BASE_URL=http://fake BXRIG_INSTALL_ALLOW_ROOT=1 BXRIG_PUBKEY_B64="${PUB:-$(base64 -w0 "$tmp/pub.pem")}" PATH="$tmp/bin:$PATH" LOG="$LOG" NO_COLOR=1 bash "$script" "$@"; }
  pcode() { set +e; prun "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
  : > "$LOG"; rm -f "$tmp/srv/stable/version-latest.properties.sig"; [[ "$(pcode --yes --no-wizard)" == 1 ]] || fail 'a missing signature fails'
  ! grep -q '^stage' "$LOG" || fail 'a stage ran without a signature'
  sign; [[ "$(pcode --yes --no-wizard)" == 0 ]] || fail "a valid signature installs: $(prun --yes --no-wizard 2>&1 | tail -4)"
  out="$(prun --yes --no-wizard 2>&1)"; [[ "$out" == *"signature verified"* ]] || fail "the signature is reported: $out"
  : > "$LOG"; PUB="$(base64 -w0 "$tmp/o.pub")" pcode --yes --no-wizard | grep -q . ; [[ "$(PUB="$(base64 -w0 "$tmp/o.pub")" pcode --yes --no-wizard)" == 1 ]] || fail 'a signature by another key fails'
  ! grep -q '^stage' "$LOG" || fail 'a stage ran after a bad signature'
  printf 'version=0.12.0\ncommit=abc\nsha256=%s\nbootstrap_sha256=%s\nx=1\n' "$asha" "$bsha" > "$tmp/srv/stable/version-latest.properties"
  [[ "$(pcode --yes --no-wizard)" == 1 ]] || fail 'edited release information fails'
  printf 'version=0.12.0\ncommit=abc\nsha256=%s\nbootstrap_sha256=%s\n' "0000" "$bsha" > "$tmp/srv/stable/version-latest.properties"; sign
  [[ "$(pcode --yes --no-wizard)" == 1 ]] || fail 'a binary that does not match the signed hash fails'
fi
# root is refused
rc=0; env HOME="$tmp/home" BXRIG_BASE_URL=http://fake PATH="$tmp/bin:$PATH" NO_COLOR=1 bash "$script" --yes >/dev/null 2>&1 || rc=$?
[[ "$(id -u)" != 0 || "$rc" == 1 ]] || fail 'root is refused'
echo "web-install-test ok"

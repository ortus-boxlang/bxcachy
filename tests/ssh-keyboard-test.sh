#!/usr/bin/env bash
# `bxcachy ssh key` and `bxcachy setup keyboard` with fake ssh-keygen and kwriteconfig6. Usage: ssh-keyboard-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home"; export LOG="$tmp/log"; : > "$LOG"
cat > "$tmp/bin/ssh-keygen" <<'SH'
#!/usr/bin/env bash
echo "ssh-keygen $*" >> "$LOG"
while [[ $# -gt 0 ]]; do [[ "$1" == -f ]] && f="$2"; shift; done
echo "private" > "$f"; echo "ssh-ed25519 AAAA fake" > "$f.pub"
SH
printf '#!/usr/bin/env bash\necho "kwriteconfig6 $*" >> "$LOG"\n' > "$tmp/bin/kwriteconfig6"
chmod +x "$tmp/bin"/*
run() { env HOME="$tmp/home" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

# ssh key
[[ "$(code "$binary" ssh key)" == 2 ]] || fail 'no --yes exits 2'
[[ ! -e "$tmp/home/.ssh/id_ed25519" ]] || fail 'the plan created a key'
run "$binary" ssh key --dry-run --json --email=ada@example.com | jq -e '.dry_run and .data.command == ["ssh-keygen","-t","ed25519","-f","'"$tmp"'/home/.ssh/id_ed25519","-C","ada@example.com"]' >/dev/null || fail 'dry-run command'
run "$binary" ssh key --yes --email=ada@example.com | grep -q 'ssh-ed25519 AAAA fake' || fail 'create prints the public key'
[[ "$(stat -c %a "$tmp/home/.ssh")" == 700 ]] || fail '.ssh is mode 700'
grep -q 'ssh-keygen -t ed25519 -f .*/id_ed25519 -C ada@example.com' "$LOG" || fail "ssh-keygen args: $(cat "$LOG")"
: > "$LOG"; echo mine > "$tmp/home/.ssh/id_ed25519"
run "$binary" ssh key --yes | grep -q 'already exists' || fail 'an existing key is kept'
[[ ! -s "$LOG" && "$(cat "$tmp/home/.ssh/id_ed25519")" == mine ]] || fail 'an existing key was touched'
rm -f "$tmp/home/.ssh/id_ed25519"; mkdir -p "$tmp/nobin"; ln -sf "$(command -v sh)" "$tmp/nobin/sh"
set +e; env HOME="$tmp/home" PATH="$tmp/nobin" "$binary" ssh key --yes >/dev/null 2>&1; rc=$?; set -e; [[ "$rc" == 4 ]] || fail "no ssh-keygen exits 4 (got $rc)"

# Plasma keyboard
: > "$LOG"
[[ "$(code "$binary" setup keyboard --layouts=us-intl,es)" == 2 ]] || fail 'keyboard without --yes exits 2'
[[ ! -s "$LOG" ]] || fail 'the keyboard plan wrote something'
run "$binary" setup keyboard --layouts=us-intl,es --dry-run --json | jq -e '.data.layout_list == "us,es" and .data.variant_list == "intl,"' >/dev/null || fail 'layout and variant lists'
run "$binary" setup keyboard --layouts=us-intl,es --yes | grep -q 'Log out and in' || fail 'keyboard --yes'
grep -q 'kwriteconfig6 --file kxkbrc --group Layout --key LayoutList us,es' "$LOG" || fail "LayoutList: $(cat "$LOG")"
grep -q 'kwriteconfig6 --file kxkbrc --group Layout --key VariantList intl,' "$LOG" || fail 'VariantList'
grep -q 'kwriteconfig6 --file kxkbrc --group Layout --key Options grp:alt_shift_toggle' "$LOG" || fail 'Alt+Shift switching with two layouts'
grep -q -- '--key Use true' "$LOG" || fail 'Use=true'
: > "$LOG"; run "$binary" setup keyboard --layouts=es --yes >/dev/null; grep -q -- '--key Options $' "$LOG" || grep -q -- '--key Options' "$LOG" || fail 'a single layout clears the switch option'
[[ "$(code "$binary" setup keyboard --layouts=klingon --yes)" == 4 ]] || fail 'an unknown layout exits 4'
set +e; env HOME="$tmp/home" PATH="$tmp/nobin" "$binary" setup keyboard --layouts=us --yes >/dev/null 2>&1; rc=$?; set -e; [[ "$rc" == 4 ]] || fail "no kwriteconfig6 exits 4 (got $rc)"
echo "ssh-keyboard-test: ok"

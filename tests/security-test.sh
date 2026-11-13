#!/usr/bin/env bash
# `bxcachy security ...` with a fake /etc/pam.d, /etc/sudoers.d, sudo, pacman, visudo, systemctl. Usage: security-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home/.config" "$tmp/pam" "$tmp/sudoers"; export LOG="$tmp/log"; : > "$LOG"
cat > "$tmp/pam/sudo" <<'P'
#%PAM-1.0
auth		include		system-auth
account		include		system-auth
session		include		system-auth
P
cp "$tmp/pam/sudo" "$tmp/sudo.original"
printf '#!/usr/bin/env bash\n[[ "$1" == --version ]] && { echo "Sudo version 1.9"; exit 0; }\necho "sudo $*" >> "$LOG"\nexec "$@"\n' > "$tmp/bin/sudo"
printf '#!/usr/bin/env bash\necho "pacman $*" >> "$LOG"\ncase "$1" in -Q) exit 1 ;; esac\n' > "$tmp/bin/pacman"
printf '#!/usr/bin/env bash\necho "systemctl $*" >> "$LOG"\n[[ "$1" == is-active ]] && exit "${ACTIVE:-3}"\nexit 0\n' > "$tmp/bin/systemctl"
# visudo -cf FILE: fails when the file has the word BROKEN
printf '#!/usr/bin/env bash\necho "visudo $*" >> "$LOG"\n! grep -q BROKEN "$2"\n' > "$tmp/bin/visudo"
printf '#!/usr/bin/env bash\necho "fprintd-enroll $*" >> "$LOG"\n' > "$tmp/fprintd-enroll.real"
printf '#!/usr/bin/env bash\necho "pamu2fcfg $*" >> "$LOG"\necho "mykey" \n' > "$tmp/pamu2fcfg.real"
printf '#!/usr/bin/env bash\nif [[ "$1" == -u ]]; then echo 1000; else /usr/bin/id "$@"; fi\n' > "$tmp/bin/id"
chmod +x "$tmp/bin"/* "$tmp"/*.real
run() { env HOME="$tmp/home" USER="${SUSER:-dev}" BXCACHY_PAM_DIR="$tmp/pam" BXCACHY_SUDOERS_DIR="$tmp/sudoers" PATH="$tmp/bin:$PATH" LOG="$LOG" ACTIVE="${ACTIVE:-3}" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
has() { grep -qF -- "$1" "$LOG"; }

run "$binary" security status --json | jq -e '(.data.fingerprint.sudo | not) and (.data.passwordless_sudo | not) and (.data.fido2.key_registered | not)' >/dev/null || fail 'status'
[[ "$(code "$binary" security nonsense)" == 2 ]] || fail 'usage exits 2'

# ---- fingerprint: one sufficient line before the first auth line, only in sudo, with a backup ----
[[ "$(code "$binary" security fingerprint on)" == 2 ]] || fail 'without --yes it is a plan'
cmp -s "$tmp/pam/sudo" "$tmp/sudo.original" || fail 'the plan changed PAM'
run "$binary" security fingerprint on --dry-run | grep -q 'auth sufficient pam_fprintd.so' || fail 'the plan prints the exact PAM line'
cmp -s "$tmp/pam/sudo" "$tmp/sudo.original" || fail 'dry run changed PAM'
run "$binary" security fingerprint on --yes >/dev/null
[[ "$(sed -n 2p "$tmp/pam/sudo")" == 'auth sufficient pam_fprintd.so # bxcachy fingerprint' ]] || fail "line position: $(cat "$tmp/pam/sudo")"
[[ "$(sed -n 3p "$tmp/pam/sudo")" == *'include'*'system-auth' ]] && grep -q 'session' "$tmp/pam/sudo" || fail 'the original lines are intact'
cmp -s "$tmp/pam/sudo.bxcachy-backup" "$tmp/sudo.original" || fail 'the original is kept as a backup'
has 'pacman -S --needed --noconfirm fprintd' || fail 'fprintd is installed'
[[ "$(grep -c 'pam_fprintd' "$tmp/pam/sudo")" == 1 ]] || fail 'one line'
run "$binary" security fingerprint on --yes >/dev/null; [[ "$(grep -c 'pam_fprintd' "$tmp/pam/sudo")" == 1 ]] || fail 'running it twice added a second line'
run "$binary" security status --json | jq -e '.data.fingerprint.sudo' >/dev/null || fail 'status sees it'
[[ ! -e "$tmp/pam/login" ]] || fail 'only sudo is touched'
run "$binary" security fingerprint off --yes >/dev/null; cmp -s "$tmp/pam/sudo" "$tmp/sudo.original" || fail "off restores the file: $(cat "$tmp/pam/sudo")"
cp "$tmp/fprintd-enroll.real" "$tmp/bin/fprintd-enroll"; : > "$LOG"; run "$binary" security fingerprint enroll --yes >/dev/null; has 'fprintd-enroll' || fail 'enroll'

# ---- a PAM file without an auth line is left alone ----
cp "$tmp/pam/sudo" "$tmp/pam/sudo.keep"; printf '#%%PAM-1.0\nsession include system-auth\n' > "$tmp/pam/sudo"
[[ "$(code "$binary" security fingerprint on --yes)" == 4 ]] || fail 'no auth line exits 4'
cp "$tmp/pam/sudo.keep" "$tmp/pam/sudo"

# ---- fido2: refuses until a key is registered ----
[[ "$(code "$binary" security fido2 on --yes)" == 4 ]] || fail 'fido2 on without a registered key exits 4'
cp "$tmp/pamu2fcfg.real" "$tmp/bin/pamu2fcfg"; run "$binary" security fido2 register --yes >/dev/null; [[ -s "$tmp/home/.config/Yubico/u2f_keys" ]] || fail 'register wrote the key file'
run "$binary" security fido2 on --yes >/dev/null; grep -q '^auth sufficient pam_u2f.so cue # bxcachy fido2$' "$tmp/pam/sudo" || fail 'fido2 line'
run "$binary" security fido2 off --yes >/dev/null; ! grep -q pam_u2f "$tmp/pam/sudo" || fail 'fido2 off'

# ---- ssh server ----
: > "$LOG"; run "$binary" security ssh-server on --yes >/dev/null; has 'pacman -S --needed --noconfirm openssh' && has 'systemctl enable --now sshd.service' || fail "ssh on: $(cat "$LOG")"
run "$binary" security ssh-server off --yes >/dev/null; has 'systemctl disable --now sshd.service' || fail 'ssh off'
[[ "$(code "$binary" security ssh-server on)" == 2 ]] || fail 'ssh on without --yes is a plan'

# ---- passwordless sudo: validated with visudo first ----
[[ "$(code "$binary" security passwordless-sudo on)" == 2 ]] || fail 'passwordless sudo without --yes is a plan'
[[ ! -e "$tmp/sudoers/50-bxcachy-nopasswd" ]] || fail 'the plan wrote the file'
run "$binary" security passwordless-sudo on --dry-run | grep -q 'dev ALL=(ALL:ALL) NOPASSWD: ALL' || fail 'the plan shows the line'
: > "$LOG"; run "$binary" security passwordless-sudo on --yes >/dev/null
grep -q '^dev ALL=(ALL:ALL) NOPASSWD: ALL$' "$tmp/sudoers/50-bxcachy-nopasswd" && has 'visudo -cf' || fail 'sudoers file written after visudo'
has 'install -Dm440 -o root -g root' || fail 'sudoers permissions'
run "$binary" security status --json | jq -e '.data.passwordless_sudo' >/dev/null || fail 'status sees passwordless sudo'
run "$binary" security passwordless-sudo off --yes >/dev/null; [[ ! -e "$tmp/sudoers/50-bxcachy-nopasswd" ]] || fail 'off removes it'
[[ "$(SUSER='bad user;x' code "$binary" security passwordless-sudo on --yes)" == 4 ]] || fail 'an unsafe user name is refused'
[[ ! -e "$tmp/sudoers/50-bxcachy-nopasswd" ]] || fail 'an unsafe name wrote a file'
echo "security-test: ok"

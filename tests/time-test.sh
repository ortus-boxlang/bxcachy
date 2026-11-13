#!/usr/bin/env bash
# `bxcachy time ...` with fake timedatectl, systemctl, sudo, pacman, yay, tzupdate. Usage: time-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/sd" "$tmp/gc" "$tmp/fake"; export LOG="$tmp/log"; : > "$LOG"
echo UTC > "$tmp/fake/zone"
cat > "$tmp/bin/timedatectl" <<'F'
#!/usr/bin/env bash
echo "timedatectl $*" >> "$LOG"
case "$1" in
  show) printf 'Timezone=%s\nNTP=yes\nNTPSynchronized=yes\nLocalRTC=no\n' "$(cat "$FAKE/zone")" ;;
  list-timezones) printf 'UTC\nEurope/Madrid\nAmerica/New_York\n' ;;
  set-timezone) echo "$2" > "$FAKE/zone" ;;
esac
exit 0
F
printf '#!/usr/bin/env bash\necho "systemctl $*" >> "$LOG"\n[[ "$1" == is-active ]] && exit "${ACTIVE:-3}"\nexit 0\n' > "$tmp/bin/systemctl"
printf '#!/usr/bin/env bash\n[[ "$1" == --version ]] && { echo "Sudo version 1.9"; exit 0; }\necho "sudo $*" >> "$LOG"\nexec "$@"\n' > "$tmp/bin/sudo"
cat > "$tmp/bin/pacman" <<'F'
#!/usr/bin/env bash
echo "pacman $*" >> "$LOG"
case "$1" in -Q) exit 1 ;; -Qq) true ;; esac
exit 0
F
printf '#!/usr/bin/env bash\necho "yay $*" >> "$LOG"\n' > "$tmp/bin/yay"
printf '#!/usr/bin/env bash\necho "tzupdate $*" >> "$LOG"\necho Europe/Madrid > "$FAKE/zone"\n' > "$tmp/tzupdate.real"
printf '#!/usr/bin/env bash\nif [[ "$1" == -u ]]; then echo 1000; else /usr/bin/id "$@"; fi\n' > "$tmp/bin/id"
printf '#!/usr/bin/env bash\necho x86_64\n' > "$tmp/bin/uname"; printf 'ID=cachyos\n' > "$tmp/os"
chmod +x "$tmp/bin"/* "$tmp/tzupdate.real"
run() { env HOME="$tmp/home" USER=dev BXCACHY_OS_RELEASE="$tmp/os" BXCACHY_STATE_HOME="$tmp/state" BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_SYSTEMD_DIR="$tmp/sd" BXCACHY_GEOCLUE_DIR="$tmp/gc" PATH="$tmp/bin:$PATH" LOG="$LOG" FAKE="$tmp/fake" ACTIVE="${ACTIVE:-3}" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
has() { grep -qF -- "$1" "$LOG"; }

run "$binary" time status --json | jq -e '.data.timezone == "UTC" and .data.ntp and (.data.automatic_zone | not)' >/dev/null || fail 'status'
[[ "$(code "$binary" time nonsense)" == 2 ]] || fail 'usage exits 2'
run "$binary" time zone | grep -qx UTC || fail 'zone shows the current one'
run "$binary" time zone --list | grep -qx 'Europe/Madrid' || fail 'zone --list'

# ---- zone: a plan without --yes, validated against the list ----
[[ "$(code "$binary" time zone Europe/Madrid)" == 2 ]] || fail 'zone without --yes is a plan'
[[ "$(cat "$tmp/fake/zone")" == UTC ]] || fail 'the plan changed the zone'
[[ "$(code "$binary" time zone Mars/Olympus --yes)" == 4 ]] || fail 'an unknown zone exits 4'
run "$binary" time zone Europe/Madrid --dry-run --json | jq -e '.dry_run and (.data.commands[0] == "sudo timedatectl set-timezone Europe/Madrid")' >/dev/null || fail 'dry run'
run "$binary" time zone America/New_York --yes >/dev/null; [[ "$(cat "$tmp/fake/zone")" == America/New_York ]] && has 'sudo timedatectl set-timezone America/New_York' || fail 'zone set'

# ---- ntp ----
run "$binary" time ntp off --yes >/dev/null; has 'timedatectl set-ntp false' || fail 'ntp off'
[[ "$(code "$binary" time ntp maybe)" == 2 ]] || fail 'bad ntp'

# ---- sync: tzupdate (installed from the AUR when missing) ----
echo UTC > "$tmp/fake/zone"; : > "$LOG"
run "$binary" time sync --dry-run | grep -q 'install tzupdate' || fail 'sync plan mentions the install'
cp "$tmp/tzupdate.real" "$tmp/bin/tzupdate"
run "$binary" time sync --yes | grep -q 'UTC -> Europe/Madrid' || fail "sync changes the zone: $(cat "$LOG")"
has 'sudo tzupdate' || fail 'sync runs tzupdate with sudo'

# ---- auto on: geoclue + automatic-timezoned, a unit and a geoclue drop-in ----
: > "$LOG"
[[ "$(code "$binary" time auto on)" == 2 ]] || fail 'auto on without --yes is a plan'
[[ ! -e "$tmp/sd/automatic-timezoned.service" ]] || fail 'the plan wrote the unit'
run "$binary" time auto on --dry-run | grep -q '^Privacy:' || fail 'the plan states the privacy tradeoff'
run "$binary" time auto on --yes >/dev/null
grep -q '^ExecStart=/usr/bin/automatic-timezoned$' "$tmp/sd/automatic-timezoned.service" && grep -q '^Requires=geoclue.service$' "$tmp/sd/automatic-timezoned.service" || fail 'unit file'
grep -q '^whitelist=$' "$tmp/gc/90-bxcachy-timezone.conf" && grep -q '^\[automatic-timezoned\]$' "$tmp/gc/90-bxcachy-timezone.conf" && grep -q '^allowed=true$' "$tmp/gc/90-bxcachy-timezone.conf" || fail 'geoclue drop-in'
has 'pacman -S --needed --noconfirm geoclue' && has 'yay' && has 'automatic-timezoned' || fail "install steps: $(cat "$LOG")"
has 'sudo systemctl enable --now automatic-timezoned.service' || fail 'the service is enabled'
ACTIVE=0 run "$binary" time status --json | jq -e '.data.automatic_zone' >/dev/null || fail 'status sees the daemon'

# ---- auto off ----
: > "$LOG"; run "$binary" time auto off --yes >/dev/null
has 'systemctl disable --now automatic-timezoned.service' && [[ ! -e "$tmp/sd/automatic-timezoned.service" && ! -e "$tmp/gc/90-bxcachy-timezone.conf" ]] || fail 'auto off removes the files'
echo "time-test: ok"

#!/usr/bin/env bash
# `bxcachy power ...` with fake powerprofilesctl, systemctl, sudo and a fake /sys and /proc. Usage: power-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/sys/BAT0" "$tmp/sys/AC" "$tmp/logind"; export LOG="$tmp/log"; : > "$LOG"
echo 82 > "$tmp/sys/BAT0/capacity"; echo Discharging > "$tmp/sys/BAT0/status"
printf 'MemTotal:       16000000 kB\nSwapTotal:       8000000 kB\n' > "$tmp/meminfo"
cat > "$tmp/bin/powerprofilesctl" <<'F'
#!/usr/bin/env bash
echo "powerprofilesctl $*" >> "$LOG"
[[ "$1" == get ]] && echo balanced
exit 0
F
printf '#!/usr/bin/env bash\necho "systemctl $*" >> "$LOG"\n[[ "$1" == is-active ]] && exit "${ACTIVE:-0}"\nexit 0\n' > "$tmp/bin/systemctl"
printf '#!/usr/bin/env bash\necho "sudo $*" >> "$LOG"\nexec "$@"\n' > "$tmp/bin/sudo"
printf '#!/usr/bin/env bash\necho "pacman $*" >> "$LOG"\n' > "$tmp/bin/pacman"
chmod +x "$tmp/bin"/*
run() { env HOME="$tmp/home" BXCACHY_POWER_DIR="${POWER_DIR:-$tmp/sys}" BXCACHY_LOGIND_DIR="$tmp/logind" BXCACHY_MEMINFO="$tmp/meminfo" PATH="$tmp/bin:$PATH" LOG="$LOG" ACTIVE="${ACTIVE:-0}" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
has() { grep -qF -- "$1" "$LOG"; }

run "$binary" power status --json | jq -e '(.data.battery[0].percent == 82) and .data.profile == "balanced" and .data.lid == "default"' >/dev/null || fail 'status'
[[ "$(code "$binary" power nonsense)" == 2 ]] || fail 'usage exits 2'

# ---- profile ----
run "$binary" power profile saver >/dev/null; has 'powerprofilesctl set power-saver' || fail 'saver is power-saver'
run "$binary" power profile performance >/dev/null; has 'powerprofilesctl set performance' || fail 'performance'
run "$binary" power profile --json | jq -e '.data.profile == "balanced"' >/dev/null || fail 'profile shows the current one'
[[ "$(code "$binary" power profile turbo)" == 2 ]] || fail 'bad profile exits 2'
run "$binary" power profile saver --dry-run --json | jq -e '.dry_run and (.data.command == "powerprofilesctl set power-saver")' >/dev/null || fail 'profile dry run'

# ---- lid: a logind drop-in, only with --yes ----
[[ "$(code "$binary" power lid lock)" == 2 ]] || fail 'lid without --yes exits 2'
[[ ! -e "$tmp/logind/50-bxcachy-lid.conf" ]] || fail 'lid wrote without --yes'
run "$binary" power lid lock --dry-run >/dev/null; [[ ! -e "$tmp/logind/50-bxcachy-lid.conf" ]] || fail 'dry run wrote'
run "$binary" power lid lock --yes >/dev/null
grep -q '^HandleLidSwitch=lock$' "$tmp/logind/50-bxcachy-lid.conf" && grep -q '^HandleLidSwitchExternalPower=lock$' "$tmp/logind/50-bxcachy-lid.conf" && grep -q '^HandleLidSwitchDocked=ignore$' "$tmp/logind/50-bxcachy-lid.conf" || fail "lid file: $(cat "$tmp/logind/50-bxcachy-lid.conf")"
has 'sudo install -Dm644' || fail 'the file is written with sudo install'
run "$binary" power status --json | jq -e '.data.lid == "lock"' >/dev/null || fail 'status reads the lid action back'
[[ "$(code "$binary" power lid sideways --yes)" == 2 ]] || fail 'bad lid action'

# ---- setup: only with a battery ----
: > "$LOG"; POWER_DIR="$tmp/none" run "$binary" power setup --yes --json | jq -e '.data.skipped == "no battery"' >/dev/null || fail 'a desktop skips setup'
! has 'pacman' || fail 'a desktop installed packages'
[[ "$(code "$binary" power setup)" == 2 ]] || fail 'setup without --yes is a plan (2)'
run "$binary" power setup --dry-run | grep -q 'pacman -S --needed --noconfirm power-profiles-daemon upower' || fail 'plan lists the packages'
: > "$LOG"; run "$binary" power setup --yes >/dev/null
has 'sudo pacman -S --needed --noconfirm power-profiles-daemon upower' && has 'sudo systemctl enable --now power-profiles-daemon.service upower.service' || fail "setup: $(cat "$LOG")"
: > "$LOG"; POWER_DIR="$tmp/none" run "$binary" power setup --yes --force >/dev/null; has 'pacman -S' || fail '--force installs on a desktop'

# ---- doctor ----
run "$binary" power doctor --json | jq -e '(.data.checks | map(select(.id == "hibernation" and (.ok | not))) | length == 1) and (.data.checks | map(select(.id == "battery")) | length == 1)' >/dev/null || fail 'doctor flags swap smaller than RAM'
printf 'MemTotal:       16000000 kB\nSwapTotal:      16000000 kB\n' > "$tmp/meminfo"
run "$binary" power doctor --json | jq -e '.data.checks | map(select(.id == "hibernation" and .ok)) | length == 1' >/dev/null || fail 'doctor accepts enough swap'
ACTIVE=3 run "$binary" power doctor --json | jq -e '.data.problems >= 2' >/dev/null || fail 'inactive daemons are problems'
POWER_DIR="$tmp/none" run "$binary" power doctor --json | jq -e '(.data.checks | map(.id) | index("hibernation")) == null' >/dev/null || fail 'a desktop skips the laptop checks'
echo "power-test: ok"

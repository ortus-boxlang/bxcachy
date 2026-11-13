#!/usr/bin/env bash
# `bxcachy toggle|dns|kernel` with fake noctalia, nmcli, pacman, uname, sudo. Usage: tweaks-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home"; export LOG="$tmp/log"; : > "$LOG"
printf '#!/usr/bin/env bash\necho "noctalia $*" >> "$LOG"\n' > "$tmp/bin/noctalia"
cat > "$tmp/bin/nmcli" <<'F'
#!/usr/bin/env bash
echo "nmcli $*" >> "$LOG"
if [[ "$*" == *"connection show --active"* ]]; then printf 'Wired:802-3-ethernet:enp3s0\nlo:loopback:lo\nmy vpn:wireguard:wg0\ndocker0:bridge:docker0\n'; exit 0; fi
if [[ "$*" == *"-g ipv4.dns"* ]]; then printf '1.1.1.1,1.0.0.1\n\n'; exit 0; fi
exit 0
F
cat > "$tmp/bin/pacman" <<'F'
#!/usr/bin/env bash
echo "pacman $*" >> "$LOG"
case "$1" in
  -Qq) printf 'linux-cachyos\nlinux-cachyos-lts\nlinux-firmware\nlinux-api-headers\nlinux-cachyos-headers\nbash\n' ;;
  -Ssq) printf 'linux-cachyos\nlinux-cachyos-bore\nlinux-cachyos-lts\nlinux-cachyos-nvidia\nlinux-cachyos-headers\nlinux-cachyos-rc\n' ;;
  -Si) [[ "$2" == linux-cachyos-bore || "$2" == linux-zen ]] && exit 0 || exit 1 ;;
esac
exit 0
F
printf '#!/usr/bin/env bash\n[[ "$1" == -r ]] && { echo "${KERNEL:-6.12.5-2-cachyos}"; exit 0; }\necho Linux\n' > "$tmp/bin/uname"
printf '#!/usr/bin/env bash\n[[ "$1" == --version ]] && { echo "Sudo version 1.9"; exit 0; }\necho "sudo $*" >> "$LOG"\nexec "$@"\n' > "$tmp/bin/sudo"
chmod +x "$tmp/bin"/*
run() { env HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
has() { grep -qF -- "$1" "$LOG"; }

# ---- toggle ----
run "$binary" toggle stay-awake on >/dev/null; has 'noctalia msg caffeine-enable' || fail 'on'
run "$binary" toggle stay-awake off >/dev/null; has 'noctalia msg caffeine-disable' || fail 'off'
run "$binary" toggle stay-awake >/dev/null; has 'noctalia msg caffeine-toggle' || fail 'toggle'
[[ "$(code "$binary" toggle stay-awake maybe)" == 2 && "$(code "$binary" toggle nothing)" == 2 ]] || fail 'bad toggle exits 2'
run "$binary" toggle stay-awake on --dry-run --json | jq -e '.dry_run and .data.command == "noctalia msg caffeine-enable"' >/dev/null || fail 'toggle dry run'
mv "$tmp/bin/noctalia" "$tmp/n.off"; [[ "$(code "$binary" toggle stay-awake on)" == 4 ]] || fail 'no Noctalia exits 4'; mv "$tmp/n.off" "$tmp/bin/noctalia"

# ---- dns ----
run "$binary" dns --json | jq -e '.data.connections | length == 1 and .[0].connection == "Wired"' >/dev/null || fail 'dns lists only the real active connection'
[[ "$(code "$binary" dns cloudflare)" == 2 ]] || fail 'dns without --yes is a plan'
: > "$LOG"; run "$binary" dns cloudflare --dry-run >/dev/null; ! has 'connection modify' || fail 'dry run modified'
run "$binary" dns cloudflare --yes >/dev/null
has 'nmcli connection modify Wired ipv4.dns 1.1.1.1 1.0.0.1 ipv4.ignore-auto-dns yes ipv6.dns 2606:4700:4700::1111 2606:4700:4700::1001 ipv6.ignore-auto-dns yes' || fail "cloudflare: $(cat "$LOG")"
has 'nmcli connection up Wired' || fail 'the connection is brought up'
run "$binary" dns quad9 --yes >/dev/null; has 'ipv4.dns 9.9.9.9 149.112.112.112' || fail 'quad9'
run "$binary" dns google --yes >/dev/null; has 'ipv4.dns 8.8.8.8 8.8.4.4' || fail 'google'
run "$binary" dns dhcp --yes >/dev/null; has 'ipv4.ignore-auto-dns no' || fail 'dhcp'
run "$binary" dns custom 9.9.9.10,2620:fe::10 --yes >/dev/null; has 'ipv4.dns 9.9.9.10' && has 'ipv6.dns 2620:fe::10' || fail 'custom'
[[ "$(code "$binary" dns custom not-an-ip --yes)" == 2 && "$(code "$binary" dns nowhere --yes)" == 2 ]] || fail 'bad dns exits 2'

# ---- kernel ----
run "$binary" kernel list --json | jq -e '.data.running == "6.12.5-2-cachyos" and (.data.installed == ["linux-cachyos","linux-cachyos-lts"]) and (.data.available == ["linux-cachyos-bore"])' >/dev/null || fail "kernel list: $(run "$binary" kernel list --json)"
[[ "$(code "$binary" kernel install linux-cachyos-bore)" == 2 ]] || fail 'install without --yes is a plan'
: > "$LOG"; run "$binary" kernel install linux-cachyos-bore --yes >/dev/null
has 'sudo pacman -S --needed --noconfirm linux-cachyos-bore linux-cachyos-bore-headers' || fail 'kernel install'
[[ "$(code "$binary" kernel install linux-nonexistent --yes)" == 4 ]] || fail 'a kernel not in the repos exits 4'
[[ "$(code "$binary" kernel install 'linux; rm' --yes)" == 2 ]] || fail 'a bad name exits 2'
[[ "$(code "$binary" kernel remove linux-cachyos --yes)" == 4 ]] || fail 'the running kernel is not removed'
: > "$LOG"; run "$binary" kernel remove linux-cachyos-lts --yes >/dev/null; has 'sudo pacman -Rns --noconfirm linux-cachyos-lts linux-cachyos-lts-headers' || fail 'remove a kernel that is not running'
KERNEL=6.12.5-1-cachyos-lts run "$binary" kernel remove linux-cachyos --yes >/dev/null || fail 'removing linux-cachyos while running lts must work'
[[ "$(KERNEL=6.12.5-1-cachyos-lts code "$binary" kernel remove linux-cachyos-lts --yes)" == 4 ]] || fail 'the running lts kernel is not removed'
echo "tweaks-test: ok"

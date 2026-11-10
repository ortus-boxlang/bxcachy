#!/usr/bin/env bash
# `bxcachy setup xremap` and `setup undo xremap` with fake pacman, yay, sudo, systemctl and id. Usage: xremap-test.sh [binary]
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home"
export LOG="$tmp/log"; : > "$LOG"
cat > "$tmp/bin/pacman" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  -Qq) [[ -f "$LOG.installed" ]] && cat "$LOG.installed" || true ;;
  -Rs) echo "pacman $*" >> "$LOG"; rm -f "$LOG.installed" ;;
  --version) echo "Pacman v7.0" ;;
  *) exit 9 ;;
esac
MOCK
printf '#!/usr/bin/env bash\n[[ "$1" == --version ]] && exit 0\necho "yay $*" >> "$LOG"\necho "${@: -1}" > "$LOG.installed"\n' > "$tmp/bin/yay"
printf '#!/usr/bin/env bash\n[[ "$1" == --version ]] && exit 0\necho "sudo $*" >> "$LOG"\n[[ "$2" == -Rs || "$1" == pacman ]] && exec "$@"\nexit 0\n' > "$tmp/bin/sudo"
printf '#!/usr/bin/env bash\n[[ "$1" == --version ]] && exit 0\necho "systemctl $*" >> "$LOG"\n' > "$tmp/bin/systemctl"
printf '#!/usr/bin/env bash\nif [[ "$1" == -u ]]; then echo "${MOCK_UID:-1000}"; elif [[ "$1" == -nG ]]; then echo "dev wheel"; else /usr/bin/id "$@"; fi\n' > "$tmp/bin/id"
printf '#!/usr/bin/env bash\necho x86_64\n' > "$tmp/bin/uname"
chmod +x "$tmp/bin/"*
printf 'ID=cachyos\n' > "$tmp/os"
run() { env BXCACHY_OS_RELEASE="$tmp/os" BXCACHY_STATE_HOME="$tmp/state" BXCACHY_CONFIG_HOME="$tmp/cfg" HOME="$tmp/home" USER=dev PATH="$tmp/bin:$PATH" XDG_CURRENT_DESKTOP="${DESKTOP-Hyprland}" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

[[ "$(code "$binary" setup xremap)" == 2 ]] || fail 'no --yes exits 2'
[[ "$(code "$binary" setup xremap --dry-run)" == 0 ]] || fail 'dry run exits 0'
[[ ! -s "$LOG" ]] || fail 'plan or dry run ran something'
[[ "$(MOCK_UID=0 code "$binary" setup xremap --yes)" == 4 ]] || fail 'root exits 4'
[[ "$(DESKTOP= code "$binary" setup xremap --yes)" == 4 ]] || fail 'unknown desktop exits 4'
[[ "$(code "$binary" setup xremap --yes)" == 0 ]] || fail 'setup xremap --yes exits 0'
grep -q 'yay -S --needed --noconfirm xremap-hypr-bin' "$LOG" || fail 'AUR install'
grep -q 'gpasswd -a dev input' "$LOG" || fail 'input group'
grep -q 'udevadm control --reload-rules' "$LOG" || fail 'udev reload'
grep -q 'systemctl --user enable xremap.service' "$LOG" || fail 'service enabled'
grep -q 'Super-c: Ctrl-Shift-c' "$tmp/cfg/xremap/config.yml" || fail 'xremap config written'
grep -q 'ExecStart=/usr/bin/xremap' "$tmp/cfg/systemd/user/xremap.service" || fail 'unit written'
jq -e '.package == "xremap-hypr-bin" and .group and .udev' "$tmp/state/bxcachy/setup-xremap.json" >/dev/null || fail 'state remembered'
[[ "$(stat -c %a "$tmp/state/bxcachy/setup-xremap.json")" == 600 ]] || fail 'state mode 600'
# undo
: > "$LOG"
[[ "$(code "$binary" setup undo xremap --yes)" == 0 ]] || fail 'undo exits 0'
grep -q 'systemctl --user disable --now xremap.service' "$LOG" || fail 'undo stops the service'
grep -q 'pacman -Rs --noconfirm xremap-hypr-bin' "$LOG" || fail 'undo removes the package'
grep -q 'gpasswd -d dev input' "$LOG" || fail 'undo removes the group it added'
[[ ! -e "$tmp/state/bxcachy/setup-xremap.json" ]] || fail 'state forgotten after undo'
[[ "$(code "$binary" setup undo xremap --yes)" == 4 ]] || fail 'second undo exits 4'
# --build=kde overrides the detected desktop (the form the CLI takes: --flag=value)
run "$binary" setup xremap --build=kde --dry-run --json | jq -e '.data.steps[0].commands[0][4] == "xremap-kde-bin"' >/dev/null || fail '--build=kde picks the kde package'
# --json stays one clean envelope even though the config files are written in the same run
: > "$LOG"; rm -rf "$tmp/cfg" "$tmp/state" "$LOG.installed"
run "$binary" setup xremap --yes --json | jq -e '.ok and (.data.done | map(.id) | index("config") != null)' >/dev/null || fail 'setup xremap --yes --json is not one clean envelope'
echo "xremap tests passed"

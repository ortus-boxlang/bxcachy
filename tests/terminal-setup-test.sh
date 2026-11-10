#!/usr/bin/env bash
# `bxcachy setup terminal` and the default terminal in `setup hyprland`, with fake pacman, sudo, id. Usage: terminal-setup-test.sh [binary]
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home"
export LOG="$tmp/log"; : > "$LOG"
cat > "$tmp/bin/pacman" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  -Q) exit 1 ;;
  -Qq) true ;;
  -S) echo "pacman $*" >> "$LOG" ;;
  --version) echo "Pacman v7.0" ;;
  *) exit 9 ;;
esac
MOCK
printf '#!/usr/bin/env bash\n[[ "$1" == --version ]] && { echo "Sudo version 1.9"; exit 0; }\n"$@"\n' > "$tmp/bin/sudo"
printf '#!/usr/bin/env bash\nif [[ "$1" == -u ]]; then echo "${MOCK_UID:-1000}"; else /usr/bin/id "$@"; fi\n' > "$tmp/bin/id"
printf '#!/usr/bin/env bash\necho x86_64\n' > "$tmp/bin/uname"
chmod +x "$tmp/bin/"*
printf 'ID=cachyos\n' > "$tmp/os"
run() { env BXCACHY_OS_RELEASE="$tmp/os" BXCACHY_STATE_HOME="$tmp/state" BXCACHY_CONFIG_HOME="$tmp/cfg" HOME="$tmp/home" USER=dev PATH="$tmp/bin:$PATH" XDG_CURRENT_DESKTOP=Hyprland LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

[[ "$(code "$binary" setup terminal)" == 2 ]] || fail 'no --yes exits 2'
run "$binary" setup terminal --dry-run --json | jq -e '.ok and (.data.steps[0].commands[0] | join(" ") | test("ghostty$"))' >/dev/null || fail 'ghostty is the default terminal'
[[ "$(code "$binary" setup terminal --default=putty --yes)" == 4 ]] || fail 'an unknown terminal exits 4'
[[ "$(code "$binary" setup terminal --also=putty --yes)" == 4 ]] || fail 'an unknown extra exits 4'

# default plus extras: packages in one call, a font config for each that has one; user files are kept
mkdir -p "$tmp/cfg/kitty"; echo 'mine' > "$tmp/cfg/kitty/kitty.conf"
run "$binary" setup terminal --also=kitty,foot,konsole --yes --json | jq -e '.ok and (.data.done | map(.id) == ["packages","config"])' >/dev/null || fail 'setup terminal --yes'
grep -q 'pacman -S --needed --noconfirm ghostty kitty foot konsole' "$LOG" || fail 'all four packages in one call'
grep -q 'font-family = JetBrainsMono Nerd Font' "$tmp/cfg/ghostty/config" || fail 'ghostty font written'
grep -q 'font=JetBrainsMono Nerd Font' "$tmp/cfg/foot/foot.ini" || fail 'foot font written'
[[ "$(cat "$tmp/cfg/kitty/kitty.conf")" == mine ]] || fail 'existing kitty.conf was overwritten'
[[ ! -e "$tmp/cfg/konsole" ]] || fail 'konsole has no starter config'

# hyprland uses the chosen terminal on Super+Enter and installs it instead of the default
rm -rf "$tmp/cfg"
run "$binary" setup hyprland --terminal=alacritty --yes >/dev/null || fail 'setup hyprland --terminal'
grep -q 'local terminal    = "alacritty"' "$tmp/cfg/hypr/hyprland.lua" || fail 'hyprland.lua uses the chosen terminal'
grep -q 'pacman -S --needed --noconfirm .*alacritty' "$LOG" || fail 'chosen terminal installed with hyprland'
rm -rf "$tmp/cfg"; run "$binary" setup hyprland --yes >/dev/null || fail 'setup hyprland'
grep -q 'local terminal    = "ghostty"' "$tmp/cfg/hypr/hyprland.lua" || fail 'ghostty is the default on Super+Enter'
[[ "$(code "$binary" setup hyprland --terminal=putty --yes)" == 4 ]] || fail 'an unknown terminal exits 4'
echo "terminal setup tests passed"

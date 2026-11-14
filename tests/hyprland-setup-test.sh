#!/usr/bin/env bash
# `bxrig setup hyprland --yes` end to end with fake pacman, sudo, id: packages, images, starter configs, shortcut files. Usage: hyprland-setup-test.sh [binary]
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
root="$(cd "$(dirname "$0")/.." && pwd)"
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
run() { env BXRIG_OS_RELEASE="$tmp/os" BXRIG_STATE_HOME="$tmp/state" BXRIG_CONFIG_HOME="$tmp/cfg" HOME="$tmp/home" USER=dev PATH="$tmp/bin:$PATH" XDG_CURRENT_DESKTOP=Hyprland LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

# plan only: nothing written
[[ "$(code "$binary" setup hyprland)" == 2 ]] || fail 'no --yes exits 2'
[[ ! -e "$tmp/cfg" && ! -e "$tmp/home/Pictures" ]] || fail 'the plan wrote files'
run "$binary" setup hyprland --dry-run --json | jq -e '.ok and (.data.steps | map(.id) | index("starter") != null)' >/dev/null || fail 'dry-run --json lists the starter step'

# a hyprland.lua the user already has is never touched
mkdir -p "$tmp/cfg/hypr"; echo '-- mine' > "$tmp/cfg/hypr/hyprland.lua"
out="$(run "$binary" setup hyprland --yes --json)" || fail 'setup hyprland --yes --json failed'
echo "$out" | jq -e '.ok and (.data.done | map(.id) == ["packages","images","starter","keys"])' >/dev/null || fail "stdout is not one clean JSON envelope with all four steps done: $out"
[[ "$(cat "$tmp/cfg/hypr/hyprland.lua")" == '-- mine' ]] || fail 'existing hyprland.lua was overwritten'
grep -q 'pacman -S --needed --noconfirm hyprland' "$LOG" || fail 'packages installed'
cmp "$tmp/home/Pictures/BxRig/box.jpg" "$root/assets/wallpapers/box.jpg" || fail 'wallpaper written'
grep -q 'custom_palette = "BxRig"' "$tmp/cfg/noctalia/config.toml" || fail 'noctalia config written'
[[ -f "$tmp/cfg/noctalia/palettes/BxRig.json" ]] || fail 'palette written'
[[ -f "$tmp/cfg/hypr/bxrig.lua" && -f "$tmp/cfg/xremap/config.yml" ]] || fail 'shortcut files written'

# fresh machine: hyprland.lua is created, loads the module; a changed Noctalia file is kept on re-run
rm -rf "$tmp/cfg" "$tmp/home/Pictures" "$tmp/state"
[[ "$(code "$binary" setup hyprland --yes)" == 0 ]] || fail 'fresh setup exits 0'
grep -q 'require("bxrig")' "$tmp/cfg/hypr/hyprland.lua" || fail 'starter hyprland.lua loads the bxrig module'
grep -q 'hl.dsp.window.close()' "$tmp/cfg/hypr/hyprland.lua" || fail 'starter has Super+Q close'
grep -q 'workspace = "2", persistent = true' "$tmp/cfg/hypr/hyprland.lua" || fail 'two persistent workspaces'
grep -q 'natural_scroll = false' "$tmp/cfg/hypr/hyprland.lua" || fail 'natural scrolling is off'
echo '# mine' >> "$tmp/cfg/noctalia/config.toml"; echo '-- also mine' >> "$tmp/cfg/hypr/hyprland.lua"
[[ "$(code "$binary" setup hyprland --yes)" == 0 ]] || fail 're-run exits 0'
grep -q '# mine' "$tmp/cfg/noctalia/config.toml" || fail 'a changed noctalia config was overwritten'
grep -q -- '-- also mine' "$tmp/cfg/hypr/hyprland.lua" || fail 'hyprland.lua was overwritten'
# the starter is valid Lua when a Lua is around
if command -v luac >/dev/null; then luac -p "$tmp/cfg/hypr/hyprland.lua" "$tmp/cfg/hypr/bxrig.lua" || fail 'starter Lua does not parse'; fi
echo "hyprland setup tests passed"

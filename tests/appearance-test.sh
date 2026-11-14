#!/usr/bin/env bash
# `bxrig appearance ...` with fake noctalia, hyprctl, fc-list, pacman and sudo. Usage: appearance-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home/Pictures/BxRig" "$tmp/fake/installed"; export LOG="$tmp/log"; : > "$LOG"
for t in noctalia hyprctl; do printf '#!/usr/bin/env bash\necho "%s $*" >> "$LOG"\n' "$t" > "$tmp/bin/$t"; done
printf '#!/usr/bin/env bash\necho "self $*" >> "$LOG"\n' > "$tmp/self"
printf '#!/usr/bin/env bash\ncat "$FAKE/fonts" 2>/dev/null\n' > "$tmp/bin/fc-list"
printf '#!/usr/bin/env bash\n[[ "$1" == --version ]] && { echo "Sudo version 1.9"; exit 0; }\necho "sudo $*" >> "$LOG"\nexec "$@"\n' > "$tmp/bin/sudo"
cat > "$tmp/bin/pacman" <<'FAKE'
#!/usr/bin/env bash
echo "pacman $*" >> "$LOG"
I="$FAKE/installed"
case "$1" in
  -Qq) ls "$I" ;;
  -Q) exit 1 ;;
  -Si) [[ "$2" == ttf-* ]] && { echo "Repository : extra"; echo "Name : $2"; exit 0; } || exit 1 ;;
  -S) shift; for a in "$@"; do [[ $a == -* ]] || touch "$I/$a"; done ;;
esac
FAKE
printf '#!/usr/bin/env bash\nif [[ "$1" == -u ]]; then echo 1000; else /usr/bin/id "$@"; fi\n' > "$tmp/bin/id"
printf '#!/usr/bin/env bash\necho x86_64\n' > "$tmp/bin/uname"; printf 'ID=cachyos\n' > "$tmp/os"
chmod +x "$tmp/bin"/* "$tmp/self"
printf 'CaskaydiaMono Nerd Font,CaskaydiaMono NF\nJetBrainsMono Nerd Font,JetBrainsMono NF\nIosevka Nerd Font,Iosevka NF\n' > "$tmp/fake/fonts"
run() { env HOME="$tmp/home" USER=dev BXRIG_OS_RELEASE="$tmp/os" BXRIG_STATE_HOME="$tmp/state" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_SELF="$tmp/self" PATH="$tmp/bin:$PATH" LOG="$LOG" FAKE="$tmp/fake" "$@"; }
hypr() { run env HYPRLAND_INSTANCE_SIGNATURE=x "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
has() { grep -qF -- "$1" "$LOG"; }
look="$tmp/cfg/bxrig/theme/look.lua"
lookhas() { grep -qF -- "$1" "$look"; }

run "$binary" appearance status --json | jq -e '.ok and .data.layout == ""' >/dev/null || fail 'status on a fresh machine'
[[ "$(code "$binary" appearance)" == 2 && "$(code "$binary" appearance nonsense)" == 2 ]] || fail 'usage exits 2'

# ---- the bar (Noctalia config-set, values are TOML; the starter's bar is called main) ----
run "$binary" appearance bar position bottom >/dev/null; has "noctalia msg config-set bar.main.position 'bottom'" || fail "bar position: $(cat "$LOG")"
[[ "$(code "$binary" appearance bar position middle)" == 2 ]] || fail 'bad position'
: > "$LOG"; run "$binary" appearance bar style glassy >/dev/null
has 'noctalia msg config-set bar.main.background_opacity 0.55' && has 'noctalia msg config-set bar.main.compositor_blur true' || fail "bar glassy: $(cat "$LOG")"
run "$binary" appearance bar style clear >/dev/null; has 'bar.main.background_opacity 0.0' || fail 'bar clear'
run "$binary" appearance bar style opaque >/dev/null; has 'bar.main.background_opacity 1.0' || fail 'bar opaque'
: > "$LOG"; run "$binary" appearance bar clock iso >/dev/null; has "noctalia msg config-set widget.clock.format '{:%Y-%m-%d %H:%M}'" || fail "clock: $(cat "$LOG")"
run "$binary" appearance bar clock sunday-12h >/dev/null; has "widget.clock.format '{:%A %-I:%M %p}'" || fail 'clock 12h'
[[ "$(code "$binary" appearance bar clock nope)" == 2 ]] || fail 'unknown clock exits 2'
: > "$LOG"; run "$binary" appearance bar battery on >/dev/null; has 'widget.battery.show_label true' && has "widget.battery.label_content 'percent'" || fail 'battery on'
run "$binary" appearance bar battery off >/dev/null; has 'widget.battery.show_label false' || fail 'battery off'
: > "$LOG"; run "$binary" appearance bar hide >/dev/null; has 'noctalia msg bar-hide' || fail 'bar hide'
run "$binary" appearance bar toggle >/dev/null; has 'noctalia msg bar-toggle' || fail 'bar toggle'
run "$binary" appearance bar clock iso --dry-run --json | jq -e '.dry_run and (.data.applied.noctalia | test("config-set widget.clock.format"))' >/dev/null || fail 'dry run'

# ---- the dock ----
: > "$LOG"; run "$binary" appearance dock mode autohide >/dev/null; has 'config-set dock.enabled true' && has 'config-set dock.auto_hide true' || fail 'dock autohide'
run "$binary" appearance dock mode always >/dev/null; has 'config-set dock.auto_hide false' || fail 'dock always'
run "$binary" appearance dock mode off >/dev/null; has 'config-set dock.enabled false' || fail 'dock off'
run "$binary" appearance dock position left >/dev/null; has "config-set dock.position 'left'" || fail 'dock position'
run "$binary" appearance dock show >/dev/null; has 'noctalia msg dock-show' || fail 'dock show'

# ---- the windows and animations: one generated Lua file for Hyprland, then a reload ----
: > "$LOG"; hypr "$binary" appearance windows gaps off >/dev/null
lookhas 'gaps_in = 0' && lookhas 'gaps_out = 0' && lookhas 'border_size = 0' && lookhas 'return {' || fail "gaps off: $(cat "$look" 2>/dev/null)"
has 'hyprctl reload' || fail 'hyprctl reload after a look change'
hypr "$binary" appearance windows corners sharp >/dev/null; lookhas 'rounding = 0' && has 'config-set shell.corner_radius_scale 0' || fail 'corners sharp'
hypr "$binary" appearance windows corners rounded >/dev/null; lookhas 'rounding = 14' && has 'config-set shell.corner_radius_scale 1' || fail 'corners rounded'
hypr "$binary" appearance windows corners theme >/dev/null; ! lookhas 'rounding' || fail 'corners theme removes the override'
hypr "$binary" appearance windows opacity glassy >/dev/null; lookhas 'active_opacity = 0.8' && lookhas 'blur = { enabled = true }' || fail 'opacity glassy'
hypr "$binary" appearance windows opacity opaque >/dev/null; lookhas 'active_opacity = 1.0' && lookhas 'enabled = false' || fail 'opacity opaque'
hypr "$binary" appearance windows one-window-ratio on >/dev/null; lookhas 'single_window_aspect_ratio = { 1, 1 }' || fail 'one-window ratio'
hypr "$binary" appearance windows gaps on >/dev/null; ! lookhas 'gaps_in' || fail 'gaps on removes the override'
hypr "$binary" appearance animations off >/dev/null; lookhas 'animations = { enabled = false }' && has 'config-set shell.animation.enabled false' || fail 'animations off'
hypr "$binary" appearance animations on >/dev/null; ! lookhas 'animations' || fail 'animations on'
[[ "$(code "$binary" appearance windows gaps maybe)" == 2 && "$(code "$binary" appearance animations sometimes)" == 2 ]] || fail 'bad window values exit 2'
# the file is the one the managed Hyprland module loads
run "$binary" keys render hyprland | grep -q 'theme/look.lua' || fail 'bxrig.lua loads look.lua'
# without Hyprland the file is written and nothing is reloaded
: > "$LOG"; run "$binary" appearance windows gaps off --json | jq -e '.data.applied.hyprland == "written"' >/dev/null || fail 'no Hyprland: written'
! has 'hyprctl reload' || fail 'reload without Hyprland'
run "$binary" appearance windows gaps off --dry-run --json | jq -e '.dry_run and (.data.applied.hyprland | test("would write"))' >/dev/null || fail 'windows dry run'

# ---- layout ----
hypr "$binary" appearance layout scrolling >/dev/null; lookhas 'layout = "scrolling"' || fail 'layout scrolling'
: > "$LOG"; run "$binary" appearance layout floating >/dev/null; has 'self layout float' || fail 'layout floating runs `layout float`'
[[ "$(code "$binary" appearance layout masonry)" == 2 ]] || fail 'bad layout'

# ---- the font: list, install, set (Noctalia + the terminal starters you have not changed) ----
run "$binary" appearance font list --json | jq -e '(.data.fonts | length == 7) and (.data.fonts | map(select(.id == "cascadia" and .installed)) | length == 1) and (.data.fonts | map(select(.id == "victor" and (.installed | not))) | length == 1)' >/dev/null || fail 'font list'
[[ "$(code "$binary" appearance font victor)" == 4 ]] || fail 'a font that is not installed exits 4'
[[ "$(code "$binary" appearance font install nope)" == 2 ]] || fail 'unknown font id'
run "$binary" appearance font install victor --yes >/dev/null; has 'pacman -S --needed --noconfirm ttf-victor-mono-nerd' || fail "font install: $(cat "$LOG")"
run "$binary" setup terminal --yes >/dev/null 2>&1 || fail "setup terminal: $(run "$binary" setup terminal --yes 2>&1 | tail -3)"
grep -q 'font-family = JetBrainsMono Nerd Font' "$tmp/cfg/ghostty/config" || fail 'the ghostty starter has the default font'
: > "$LOG"; run "$binary" appearance font cascadia --json | jq -e '.data.value == "CaskaydiaMono Nerd Font" and (.data.applied.terminals | test("updated"))' >/dev/null || fail "font set: $(run "$binary" appearance font cascadia --json)"
has "config-set shell.font_family 'CaskaydiaMono Nerd Font'" || fail 'noctalia font'
grep -q 'font-family = CaskaydiaMono Nerd Font' "$tmp/cfg/ghostty/config" || fail 'the terminal starter follows the font'
echo '# mine' >> "$tmp/cfg/ghostty/config"
run "$binary" appearance font iosevka --json | jq -e '.data.notes | map(test("ghostty")) | any' >/dev/null || fail 'a changed terminal config is kept and reported'
grep -q '^# mine' "$tmp/cfg/ghostty/config" && grep -q 'CaskaydiaMono' "$tmp/cfg/ghostty/config" || fail 'your ghostty config was rewritten'

# ---- backgrounds ----
: > "$tmp/home/Pictures/BxRig/aurora.jpg"; : > "$tmp/home/Pictures/BxRig/notes.txt"
run "$binary" appearance background list --json | jq -e '.data.images | map(.name) == ["aurora.jpg"]' >/dev/null || fail 'background list'
: > "$LOG"; run "$binary" appearance background set aurora.jpg >/dev/null; has "noctalia msg wallpaper-set $tmp/home/Pictures/BxRig/aurora.jpg" || fail "background set: $(cat "$LOG")"
run "$binary" appearance background next >/dev/null; has 'noctalia msg wallpaper-next' || fail 'next'
run "$binary" appearance background random >/dev/null; has 'noctalia msg wallpaper-random' || fail 'random'
[[ "$(code "$binary" appearance background set nothing.png)" == 4 ]] || fail 'unknown image exits 4'

# ---- apply pushes what is remembered; no Noctalia is saved-only ----
: > "$LOG"; hypr "$binary" appearance apply >/dev/null
has "config-set bar.main.position 'bottom'" && has "config-set dock.position 'left'" && has "config-set shell.font_family 'Iosevka Nerd Font'" && has 'hyprctl reload' || fail "apply: $(cat "$LOG")"
mv "$tmp/bin/noctalia" "$tmp/noctalia.off"
run "$binary" appearance bar position top --json | jq -e '.ok and (.data.applied.noctalia | test("saved only"))' >/dev/null || fail 'no Noctalia: saved only, not an error'
jq -e '.bar.position == "top"' "$tmp/cfg/bxrig/appearance.json" >/dev/null || fail 'the choice is remembered'
mv "$tmp/noctalia.off" "$tmp/bin/noctalia"
echo "appearance-test: ok"

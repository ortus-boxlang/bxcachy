#!/usr/bin/env bash
# `bxcachy runner`: provider choice, commands, doctor, launch. It must never touch keybindings. Usage: runner-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/cfg/hypr"
echo '-- my keybinds' > "$tmp/cfg/hypr/hyprland.lua"; echo '-- bxcachy' > "$tmp/cfg/hypr/bxcachy.lua"
before="$(sha256sum "$tmp/cfg/hypr/"*)"
export LOG="$tmp/log"; : > "$LOG"
printf '#!/usr/bin/env bash\necho "noctalia $*" >> "$LOG"\n' > "$tmp/bin/noctalia"
printf '#!/usr/bin/env bash\ntrue\n' > "$tmp/bin/rofi"
chmod +x "$tmp/bin/"*
run() { env BXCACHY_CONFIG_HOME="$tmp/cfg" HOME="$tmp/home" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
hypr() { XDG_CURRENT_DESKTOP=Hyprland run "$@"; }
kde() { XDG_CURRENT_DESKTOP=KDE run "$@"; }

# defaults and listing
hypr "$binary" runner list | grep -q '^launcher: system \*noctalia rofi' || fail 'Hyprland defaults to the Noctalia launcher'
kde "$binary" runner list | grep -q '^launcher: \*system noctalia' || fail 'KDE defaults to the system runner'
hypr "$binary" runner list | grep -q '^menu: \*rofi walker' || fail 'Rofi is the default menu'
hypr "$binary" runner list --json | jq -e '(.data.launchers | map(select(.current)) | .[0].id) == "noctalia" and (.data.menus | map(.id) == ["rofi","walker","vicinae","hyprrunner"])' >/dev/null || fail 'list --json'

# choices are saved at once (no --yes) and shown back
hypr "$binary" runner set rofi | grep -q 'Runner provider: rofi' || fail 'set'
hypr "$binary" runner menu-set walker | grep -q 'Menu provider: walker' || fail 'menu-set'
hypr "$binary" runner show --json | jq -e '.data.provider == "rofi" and .data.menu_provider == "walker"' >/dev/null || fail 'show --json'
[[ "$(jq -r .provider "$tmp/cfg/bxcachy/runner.json")" == rofi ]] || fail 'runner.json written'
[[ "$(code "$binary" runner set nope)" == 4 && "$(code "$binary" runner menu-set noctalia)" == 4 ]] || fail 'unknown providers exit 4'

# commands are JSON argument arrays, never shell strings
hypr "$binary" runner launcher-command rofi '["rofi","-show","run"]' >/dev/null || fail 'launcher-command'
hypr "$binary" runner menu-command walker '["walker","--dmenu","-p","{prompt}"]' >/dev/null || fail 'menu-command'
[[ "$(code "$binary" runner launcher-command rofi 'rofi -show run')" == 4 && "$(code "$binary" runner launcher-command rofi '[]')" == 4 && "$(code "$binary" runner menu-command walker '["a",""]')" == 4 && "$(code "$binary" runner launcher-command system '["x"]')" == 4 ]] || fail 'shell strings, empty arrays and empty parts are refused'
hypr "$binary" runner doctor | grep -q 'Launcher: rofi | command: rofi -show run' || fail 'doctor shows the configured launcher'
hypr "$binary" runner doctor | grep -q 'Menu: walker | command: walker --dmenu -p BxCachy' || fail 'doctor shows the menu with the prompt'
hypr "$binary" runner doctor | grep -q 'launcher executable: found' || fail 'doctor finds rofi on PATH'
hypr "$binary" runner doctor | grep -q 'menu executable: NOT FOUND' || fail 'doctor reports walker missing'
hypr "$binary" runner doctor | grep -q 'Shortcut ownership: unchanged' || fail 'doctor says shortcuts are unchanged'
hypr "$binary" runner doctor --json | jq -e '.data.launcher.found and (.data.menu.found | not) and .data.shortcuts == "unchanged"' >/dev/null || fail 'doctor --json'

# launch: noctalia runs detached; the system runner is the desktop's
hypr "$binary" runner set noctalia >/dev/null
hypr "$binary" runner launch >/dev/null || fail 'launch'
for _ in 1 2 3 4 5 6 7 8 9 10; do grep -q 'noctalia msg panel-toggle launcher' "$LOG" && break; sleep 0.3; done
grep -q 'noctalia msg panel-toggle launcher' "$LOG" || fail 'the launcher command did not run'
hypr "$binary" runner set system >/dev/null
[[ "$(code "$binary" runner launch)" == 4 ]] || fail 'launching the system runner exits 4'
hypr "$binary" runner set vicinae >/dev/null; [[ "$(code "$binary" runner launch)" == 4 ]] || fail 'a missing launcher exits 4'

# usage and bad state
[[ "$(code "$binary" runner)" == 2 && "$(code "$binary" runner set)" == 2 && "$(code "$binary" runner list extra)" == 2 && "$(code "$binary" runner bogus)" == 2 ]] || fail 'usage exits 2'
echo '{' > "$tmp/cfg/bxcachy/runner.json"; [[ "$(code "$binary" runner list)" == 4 ]] || fail 'a broken runner.json exits 4'

# it never changes keybindings
[[ "$(sha256sum "$tmp/cfg/hypr/"*)" == "$before" ]] || fail 'the runner touched the Hyprland config'
echo "runner tests passed"

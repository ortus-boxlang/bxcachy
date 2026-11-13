#!/usr/bin/env bash
# `bxcachy menu`: the control center on a fake Rofi (it plays the answers); results open in a fake terminal. Usage: menu-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/fake"
export FAKE="$tmp/fake"
printf '#!/usr/bin/env bash\ncat > /dev/null\nn=$(( $(cat "$FAKE/n" 2>/dev/null || echo 0) + 1 )); echo $n > "$FAKE/n"\nsed -n "${n}p" "$FAKE/answers"\n' > "$tmp/bin/rofi"
printf '#!/usr/bin/env bash\necho "terminal $*" >> "$FAKE/terminal.log"\n' > "$tmp/bin/ghostty"
printf '#!/usr/bin/env bash\necho "bxcachy $*" >> "$FAKE/spawn.log"\n' > "$tmp/self"
chmod +x "$tmp/bin/rofi" "$tmp/bin/ghostty" "$tmp/self"
run() { env HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_STATE_HOME="$tmp/state" BXCACHY_SELF="$tmp/self" FAKE="$FAKE" PATH="$tmp/bin:$PATH" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
wait_for() { for _ in $(seq 1 30); do [[ -s "$1" ]] && return 0; sleep 0.2; done; return 1; }

# the tree as data
run "$binary" menu items --json | jq -e '(.data.menu | map(.label)) == ["AI","Databases","All apps","BoxLang","Screenshot","Notifications","Cloud storage","Web apps","Settings"] and (.data.menu[0].children | length) == 7 and .data.menu[0].children[0].argv == ["ai","launch"]' >/dev/null || fail "menu items: $(run "$binary" menu items --json)"
run "$binary" menu items | grep -q 'Pull-down AI shell   (opens: bxcachy ai shell)' || fail 'menu items text'
run "$binary" runner menu-set rofi >/dev/null

# AI (0) -> "Open the default agent" (0): started detached, no terminal; then Back (7) and Exit (3)
printf '0\n0\n7\n9\n' > "$FAKE/answers"
run "$binary" menu || fail 'menu exits 0'
wait_for "$FAKE/spawn.log" || fail 'the spawn entry did not start'
grep -q 'bxcachy ai launch' "$FAKE/spawn.log" || fail "spawn: $(cat "$FAKE/spawn.log")"
[[ ! -s "$FAKE/terminal.log" ]] || fail 'a spawn entry opened a terminal'

# AI (0) -> "Local models: list" (4): runs in a terminal and waits for Enter
rm -f "$FAKE/n" "$FAKE/spawn.log" "$FAKE/terminal.log"; printf '0\n4\n7\n9\n' > "$FAKE/answers"
run "$binary" menu || fail 'menu (run entry)'
wait_for "$FAKE/terminal.log" || fail 'the run entry did not open a terminal'
grep -q "terminal -e sh -c .* _ $tmp/self ai models list" "$FAKE/terminal.log" || fail "run entry: $(cat "$FAKE/terminal.log")"

# All apps (2) starts `apps` detached; Settings (4) -> Shortcuts (1), and cancelling (empty answer) at the top leaves without running anything
rm -f "$FAKE/n" "$FAKE/terminal.log"; printf '8\n1\n6\n9\n' > "$FAKE/answers"
run "$binary" menu >/dev/null; wait_for "$FAKE/terminal.log" || fail 'settings entry'; grep -q 'keys show' "$FAKE/terminal.log" || fail 'Shortcuts runs keys show'
rm -f "$FAKE/n" "$FAKE/terminal.log" "$FAKE/spawn.log"; : > "$FAKE/answers"
run "$binary" menu || fail 'cancel exits 0'; sleep 0.4
[[ ! -s "$FAKE/terminal.log" && ! -s "$FAKE/spawn.log" ]] || fail 'a cancelled menu ran something'

# All apps (2): started detached like any spawn entry
rm -f "$FAKE/n" "$FAKE/spawn.log" "$FAKE/terminal.log"; printf '2\n9\n' > "$FAKE/answers"
run "$binary" menu >/dev/null; wait_for "$FAKE/spawn.log" || fail 'All apps did not start'; grep -q 'bxcachy apps' "$FAKE/spawn.log" || fail "all apps: $(cat "$FAKE/spawn.log")"

# Web apps (3) -> Create web app (0): the name and the URL are typed in the menu (Rofi takes text), then `web add NAME URL --yes` runs
rm -f "$FAKE/n" "$FAKE/spawn.log" "$FAKE/terminal.log"; printf '7\n0\nNotion\nhttps://notion.so\n0\n6\n9\n' > "$FAKE/answers"
printf '#!/usr/bin/env bash\necho "bxcachy $*" >> "$FAKE/spawn.log"\n' > "$tmp/self"
run "$binary" menu >/dev/null || fail 'create web app flow exits 0'
grep -q '^bxcachy web add Notion https://notion.so --yes$' "$FAKE/spawn.log" || fail "web add from the menu: $(cat "$FAKE/spawn.log" 2>/dev/null)"
grep -q 'Added Notion' "$FAKE/menu.in" 2>/dev/null || true
# an empty name cancels the flow without running anything
rm -f "$FAKE/n" "$FAKE/spawn.log"; printf '7\n0\n\n6\n9\n' > "$FAKE/answers"; run "$binary" menu >/dev/null; [[ ! -s "$FAKE/spawn.log" ]] || fail 'an empty name added something'
# Remove a web app (2): pick, confirm
mkdir -p "$tmp/data/applications"; printf '[Desktop Entry]\nType=Application\nName=Notion\nExec=brave --app=https://notion.so\nX-BxCachy-Web=https://notion.so\n' > "$tmp/data/applications/bxcachy-web-Notion.desktop"
rm -f "$FAKE/n" "$FAKE/spawn.log"; printf '7\n5\n0\n1\n6\n9\n' > "$FAKE/answers"; XDG_DATA_HOME="$tmp/data" run env XDG_DATA_HOME="$tmp/data" "$binary" menu >/dev/null
grep -q '^bxcachy web rm Notion --yes$' "$FAKE/spawn.log" || fail "remove from the menu: $(cat "$FAKE/spawn.log" 2>/dev/null)"
rm -f "$FAKE/n" "$FAKE/spawn.log"; printf '7\n5\n0\n0\n6\n9\n' > "$FAKE/answers"; run env XDG_DATA_HOME="$tmp/data" "$binary" menu >/dev/null; [[ ! -s "$FAKE/spawn.log" ]] || fail 'Cancel at the confirmation removed the app'
# a provider that cannot take typed text (Wofi here) opens a terminal that asks the same questions
printf '#!/usr/bin/env bash\ncat > /dev/null\nn=$(( $(cat "$FAKE/n" 2>/dev/null || echo 0) + 1 )); echo $n > "$FAKE/n"\nsed -n "${n}p" "$FAKE/answers"\n' > "$tmp/bin/wofi"; chmod +x "$tmp/bin/wofi"
run "$binary" runner menu-set wofi >/dev/null
rm -f "$FAKE/n" "$FAKE/terminal.log"; printf 'Web apps\nCreate web app\nBack\nExit\n' > "$FAKE/answers"; run "$binary" menu >/dev/null
wait_for "$FAKE/terminal.log" || fail 'the terminal fallback did not open'; grep -q "$tmp/self web add" "$FAKE/terminal.log" || fail "terminal fallback: $(cat "$FAKE/terminal.log")"
run "$binary" runner menu-set rofi >/dev/null; printf '#!/usr/bin/env bash\necho "terminal $*" >> "$FAKE/terminal.log"\n' > "$tmp/bin/ghostty"; chmod +x "$tmp/bin/ghostty"

# no terminal: a run entry is a precondition error; no menu program: exit 4
rm -f "$FAKE/n"; rm "$tmp/bin/ghostty"; printf '0\n4\n' > "$FAKE/answers"
mkdir -p "$tmp/nobin"; ln -sf "$(command -v sh)" "$tmp/nobin/sh"; ln -sf "$(command -v cat)" "$tmp/nobin/cat"; ln -sf "$(command -v sed)" "$tmp/nobin/sed"
printf '#!/bin/sh\ncat > /dev/null\nn=$(( $(cat "$FAKE/n" 2>/dev/null || echo 0) + 1 )); echo $n > "$FAKE/n"\nsed -n "${n}p" "$FAKE/answers"\n' > "$tmp/nobin/rofi"; chmod +x "$tmp/nobin/rofi"
set +e; env HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_STATE_HOME="$tmp/state" BXCACHY_SELF="$tmp/self" FAKE="$FAKE" PATH="$tmp/nobin" "$binary" menu >/dev/null 2>&1; rc=$?; set -e
[[ "$rc" == 4 ]] || fail "a run entry without a terminal exits 4 (got $rc)"
rm "$tmp/bin/rofi"; [[ "$(code "$binary" menu)" == 4 ]] || fail 'a missing menu program exits 4'
echo "menu-test: ok"

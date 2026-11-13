#!/usr/bin/env bash
# `bxcachy menu`: the control center on a fake Rofi (it plays the answers: an index for a choice, text for a typed line); results open in a
# fake terminal. Usage: menu-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
root="$(cd "$(dirname "$binary")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/fake"
export FAKE="$tmp/fake"
printf '#!/usr/bin/env bash\ncat > /dev/null\nn=$(( $(cat "$FAKE/n" 2>/dev/null || echo 0) + 1 )); echo $n > "$FAKE/n"\nsed -n "${n}p" "$FAKE/answers"\n' > "$tmp/bin/rofi"
printf '#!/usr/bin/env bash\necho "terminal $*" >> "$FAKE/terminal.log"\n' > "$tmp/bin/ghostty"
printf '#!/usr/bin/env bash\necho "xdg-open $*" >> "$FAKE/open.log"\n' > "$tmp/bin/xdg-open"
# the fake bxcachy: logs what it is asked, and answers the two listing commands the menu itself runs
cat > "$tmp/self" <<'FAKE'
#!/usr/bin/env bash
echo "bxcachy $*" >> "$FAKE/spawn.log"
if [[ "$1 $2" == "pkg installed" ]]; then echo '{"data":{"packages":[{"name":"htop","version":"3.4"},{"name":"nano","version":"8.0"}]}}'; fi
if [[ "$1 $2" == "pkg search" ]]; then echo '{"data":{"results":[{"name":"ripgrep","version":"15","repo":"extra","source":"repo","installed":false,"description":"fast grep"},{"name":"fzf","version":"0.5","repo":"extra","source":"repo","installed":true,"description":"fuzzy"}]}}'; fi
FAKE
chmod +x "$tmp/bin/rofi" "$tmp/bin/ghostty" "$tmp/bin/xdg-open" "$tmp/self"
run() { env HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_STATE_HOME="$tmp/state" BXCACHY_SELF="$tmp/self" FAKE="$FAKE" PATH="$tmp/bin:$PATH" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
wait_for() { for _ in $(seq 1 30); do [[ -s "$1" ]] && return 0; sleep 0.2; done; return 1; }
# play ANSWER...: one answer per line, fresh logs, then the menu
play() { rm -f "$FAKE/n" "$FAKE/spawn.log" "$FAKE/terminal.log" "$FAKE/open.log"; : > "$FAKE/answers"; for a in "$@"; do printf '%s\n' "$a" >> "$FAKE/answers"; done; run "$binary" menu >/dev/null; }
# the position of a path ("Appearance > Next theme") in the flat search list
flatidx() { run "$binary" menu items --json | jq -r --arg p "$1" 'def f($pre): if .kind == "sub" then (.label as $l | .children[] | f($pre + $l + " > ")) else $pre + .label end; [.data.menu[] | f("")] | index($p)'; }

# ---- the tree as data (Omarchy's skeleton plus Develop) ----
run "$binary" menu items --json | jq -e '(.data.menu | map(.label)) == ["Apps","Install","Remove","Appearance","Trigger","Setup","Update","Develop","Agent","Learn","About","System"] and .data.entries >= 120' >/dev/null || fail "menu sections: $(run "$binary" menu items --json | jq -c '.data.menu | map(.label)')"
run "$binary" menu items --json | jq -e '[.data.menu[] | select(.label == "Install") | .children[] | .label] | index("Package (repos and AUR)") == 0 and index("Catalog") == 2' >/dev/null || fail 'Install starts with package search and the catalog'
run "$binary" menu items | grep -q 'Next theme   (opens: bxcachy theme next)' || fail 'menu items text, nested'
run "$binary" menu items | grep -q '    Development   (lists the Development apps' || fail 'catalog groups are in the tree'
run "$binary" menu search 'next theme' | grep -q 'Appearance > Next theme   (opens: bxcachy theme next)' || fail 'menu search finds an entry and its command'
run "$binary" menu search zzzznothing | grep -q 'No menu entry matches' || fail 'menu search without a match'
run "$binary" menu search lock --json | jq -e '.data.results | map(.path) | index("System > Lock") != null' >/dev/null || fail 'menu search json'
# every spawn and run entry names a real command (the first word must be a known route)
run "$binary" menu items --json | jq -r 'def f: if .kind == "sub" then .children[] | f else select(.argv != null) | .argv[0] end; [.data.menu[] | f] | unique | .[]' | while read -r w; do
  c="$(set +e; run "$binary" "$w" >/dev/null 2>&1 < /dev/null; echo $?)"; [[ "$c" != 127 ]] || fail "the menu runs an unknown command: $w"
done
run "$binary" runner menu-set rofi >/dev/null

# ---- Agent (9) -> Open the default agent (0): detached, no terminal; Back (8), Exit (13) ----
play 9 0 8 13; wait_for "$FAKE/spawn.log" || fail 'the spawn entry did not start'
grep -q 'bxcachy ai launch' "$FAKE/spawn.log" || fail "spawn: $(cat "$FAKE/spawn.log")"
[[ ! -s "$FAKE/terminal.log" ]] || fail 'a spawn entry opened a terminal'
# a run entry opens a terminal and waits for Enter
play 9 4 8 13; wait_for "$FAKE/terminal.log" || fail 'the run entry did not open a terminal'
grep -q "terminal -e sh -c .* _ $tmp/self ai models list" "$FAKE/terminal.log" || fail "run entry: $(cat "$FAKE/terminal.log")"
# Apps (1) starts the app grid
play 1 13; wait_for "$FAKE/spawn.log"; grep -q 'bxcachy apps' "$FAKE/spawn.log" || fail "apps: $(cat "$FAKE/spawn.log")"
# cancelling at the top leaves without running anything
rm -f "$FAKE/n" "$FAKE/spawn.log" "$FAKE/terminal.log"; : > "$FAKE/answers"; run "$binary" menu || fail 'cancel exits 0'; sleep 0.3
[[ ! -s "$FAKE/terminal.log" && ! -s "$FAKE/spawn.log" ]] || fail 'a cancelled menu ran something'

# ---- Search (0): one flat list of every entry ----
play 0 0 13; wait_for "$FAKE/spawn.log"; grep -q 'bxcachy apps' "$FAKE/spawn.log" || fail 'search: the first flat entry is Apps'
i="$(flatidx 'Appearance > Next theme')"; [[ "$i" =~ ^[0-9]+$ ]] || fail 'flatidx'
play 0 "$i" 13; wait_for "$FAKE/spawn.log"; grep -q 'bxcachy theme next' "$FAKE/spawn.log" || fail "search runs the chosen entry: $(cat "$FAKE/spawn.log" 2>/dev/null)"
j="$(flatidx 'Learn > BxCachy docs')"; play 0 "$j" 13; wait_for "$FAKE/open.log"; grep -q 'xdg-open https://bxcachy.boxlang.io/' "$FAKE/open.log" || fail 'an open entry runs xdg-open'

# ---- pick: Appearance (4) -> Theme (0) -> the first theme in the list (0) ----
play 4 0 0 7 13; wait_for "$FAKE/spawn.log"; grep -q '^bxcachy theme set bxcachy$' "$FAKE/spawn.log" || fail "theme picker: $(cat "$FAKE/spawn.log" 2>/dev/null)"
play 4 0 '' 7 13; sleep 0.3; ! grep -q 'theme set' "$FAKE/spawn.log" 2>/dev/null || fail 'cancelling the picker ran something'

# ---- confirm: System (12) -> Reboot (3): Cancel (0) runs nothing, Yes (1) runs it ----
play 12 3 0 5 13; sleep 0.3; ! grep -q 'system reboot' "$FAKE/spawn.log" 2>/dev/null || fail 'Cancel at the confirmation rebooted'
play 12 3 1 5 13; wait_for "$FAKE/spawn.log"; grep -q '^bxcachy system reboot --yes$' "$FAKE/spawn.log" || fail "reboot after Yes: $(cat "$FAKE/spawn.log" 2>/dev/null)"
play 12 0 5 13; wait_for "$FAKE/spawn.log"; grep -q '^bxcachy system lock$' "$FAKE/spawn.log" || fail 'lock acts at once, without a confirmation'

# ---- Remove (3) -> Package (0): the explicit packages, confirm, a terminal runs the removal ----
play 3 0 0 1 6 13; wait_for "$FAKE/terminal.log"; grep -q "$tmp/self pkg remove htop --yes" "$FAKE/terminal.log" || fail "remove a package: $(cat "$FAKE/terminal.log" 2>/dev/null)"
play 3 0 0 0 6 13; sleep 0.3; [[ ! -s "$FAKE/terminal.log" ]] || fail 'Cancel at the confirmation removed the package'

# ---- Install (2) -> Package (0): type a name, pick a result, confirm; an installed result is only noted ----
play 2 0 ripgrep 0 1 9 13; wait_for "$FAKE/terminal.log"; grep -q "$tmp/self pkg install ripgrep --yes" "$FAKE/terminal.log" || fail "install from the package search: $(cat "$FAKE/terminal.log" 2>/dev/null)"
grep -q 'pkg search ripgrep --source=all' "$FAKE/spawn.log" || fail 'the menu searched through bxcachy pkg search'
play 2 0 ripgrep 1 0 9 13; sleep 0.3; [[ ! -s "$FAKE/terminal.log" ]] || fail 'an installed package was installed again'
# ask: Install (2) -> Virtual machine (4) -> Linux desktop (1): type a name
play 2 4 1 dev 4 9 13; wait_for "$FAKE/terminal.log"; grep -q "$tmp/self vm create linux dev --yes" "$FAKE/terminal.log" || fail "ask entry: $(cat "$FAKE/terminal.log" 2>/dev/null)"
# catalog: Install (2) -> Catalog (2) -> Development (0) -> the first app (0), confirm (1)
first="$(jq -r '[.apps[] | select(.group == "development")] | sort_by(.name | ascii_downcase) | .[0].id' "$root/catalog/apps.json")"
play 2 2 0 0 1 0 9 13; wait_for "$FAKE/terminal.log"; grep -q "$tmp/self install $first --yes" "$FAKE/terminal.log" || fail "catalog install of $first: $(cat "$FAKE/terminal.log" 2>/dev/null)"

# ---- web apps: create (Install > Web app > Create), typed name and URL, then `web add NAME URL --yes` ----
play 2 3 0 Notion https://notion.so 5 9 13; wait_for "$FAKE/spawn.log"
grep -q '^bxcachy web add Notion https://notion.so --yes$' "$FAKE/spawn.log" || fail "web add from the menu: $(cat "$FAKE/spawn.log" 2>/dev/null)"
play 2 3 0 '' 5 9 13; sleep 0.3; ! grep -q 'web add' "$FAKE/spawn.log" 2>/dev/null || fail 'an empty name added something'
# remove (Remove > Web app): pick, confirm
mkdir -p "$tmp/data/applications"; printf '[Desktop Entry]\nType=Application\nName=Notion\nExec=brave --app=https://notion.so\nX-BxCachy-Web=https://notion.so\n' > "$tmp/data/applications/bxcachy-web-Notion.desktop"
rm -f "$FAKE/n" "$FAKE/spawn.log"; printf '3\n2\n0\n1\n6\n13\n' > "$FAKE/answers"; run env XDG_DATA_HOME="$tmp/data" "$binary" menu >/dev/null
grep -q '^bxcachy web rm Notion --yes$' "$FAKE/spawn.log" || fail "remove a web app from the menu: $(cat "$FAKE/spawn.log" 2>/dev/null)"
rm -f "$FAKE/n" "$FAKE/spawn.log"; printf '3\n2\n0\n0\n6\n13\n' > "$FAKE/answers"; run env XDG_DATA_HOME="$tmp/data" "$binary" menu >/dev/null; [[ ! -s "$FAKE/spawn.log" ]] || fail 'Cancel at the confirmation removed the web app'

# ---- a provider that cannot take typed text (Wofi) opens a terminal that asks the same questions ----
printf '#!/usr/bin/env bash\ncat > /dev/null\nn=$(( $(cat "$FAKE/n" 2>/dev/null || echo 0) + 1 )); echo $n > "$FAKE/n"\nsed -n "${n}p" "$FAKE/answers"\n' > "$tmp/bin/wofi"; chmod +x "$tmp/bin/wofi"
run "$binary" runner menu-set wofi >/dev/null
rm -f "$FAKE/n" "$FAKE/terminal.log"; printf 'Install\nWeb app\nCreate web app\nBack\nBack\nExit\n' > "$FAKE/answers"; run "$binary" menu >/dev/null
wait_for "$FAKE/terminal.log" || fail 'the terminal fallback did not open'; grep -q "$tmp/self web add" "$FAKE/terminal.log" || fail "terminal fallback: $(cat "$FAKE/terminal.log")"
run "$binary" runner menu-set rofi >/dev/null

# ---- no terminal: a run entry is a precondition error; no menu program: exit 4 ----
rm -f "$FAKE/n"; rm "$tmp/bin/ghostty"; printf '9\n4\n' > "$FAKE/answers"
mkdir -p "$tmp/nobin"; ln -sf "$(command -v sh)" "$tmp/nobin/sh"; ln -sf "$(command -v cat)" "$tmp/nobin/cat"; ln -sf "$(command -v sed)" "$tmp/nobin/sed"
printf '#!/bin/sh\ncat > /dev/null\nn=$(( $(cat "$FAKE/n" 2>/dev/null || echo 0) + 1 )); echo $n > "$FAKE/n"\nsed -n "${n}p" "$FAKE/answers"\n' > "$tmp/nobin/rofi"; chmod +x "$tmp/nobin/rofi"
set +e; env HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_STATE_HOME="$tmp/state" BXCACHY_SELF="$tmp/self" FAKE="$FAKE" PATH="$tmp/nobin" "$binary" menu >/dev/null 2>&1; rc=$?; set -e
[[ "$rc" == 4 ]] || fail "a run entry without a terminal exits 4 (got $rc)"
rm "$tmp/bin/rofi"; [[ "$(code "$binary" menu)" == 4 ]] || fail 'a missing menu program exits 4'
echo "menu-test: ok"

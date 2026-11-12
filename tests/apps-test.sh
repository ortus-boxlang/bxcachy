#!/usr/bin/env bash
# `bxcachy apps` (the all-apps window) with fake desktop entries and a fake Rofi. Usage: apps-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/sys" "$tmp/usr" "$tmp/fake"; export FAKE="$tmp/fake"
d() { printf '[Desktop Entry]\n%s\n' "$2" > "$1"; }
d "$tmp/sys/firefox.desktop" $'Type=Application\nName=Firefox\nName[de]=Feuerfuchs\nExec=firefox %u\nIcon=firefox'
d "$tmp/sys/kitty.desktop" $'Type=Application\nName=Kitty\nExec=kitty\nIcon=kitty'
d "$tmp/sys/hidden.desktop" $'Type=Application\nName=Hidden thing\nExec=hidden\nNoDisplay=true'
d "$tmp/sys/link.desktop" $'Type=Link\nName=A link\nURL=https://example.com'
d "$tmp/sys/aaa-calc.desktop" $'Type=Application\nName=Calculator\nExec=calc --flag %F %% done'
d "$tmp/usr/kitty.desktop" $'Type=Application\nName=Kitty (mine)\nExec=kitty --mine'
d "$tmp/usr/firefox.desktop" $'Type=Application\nName=Firefox\nExec=firefox\nHidden=true'
printf '[Desktop Entry]\nType=Application\nName=Other group\nExec=x\n[Desktop Action new]\nName=New window\nExec=firefox --new-window\n' > "$tmp/sys/actions.desktop"
printf '#!/usr/bin/env bash\ncat > "$FAKE/menu.in"\nn=$(( $(cat "$FAKE/n" 2>/dev/null || echo 0) + 1 )); echo $n > "$FAKE/n"\nsed -n "${n}p" "$FAKE/answers"\n' > "$tmp/bin/rofi"
printf '#!/usr/bin/env bash\necho "launched $*" >> "$FAKE/launch.log"\n' > "$tmp/bin/calc"
chmod +x "$tmp/bin"/*
run() { env HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_APPS_DIRS="$tmp/sys:$tmp/usr" FAKE="$FAKE" PATH="$tmp/bin:$PATH" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

# list: only applications, no hidden ones, the later folder wins for the same file name, field codes removed, sorted by name
run "$binary" apps list --json | jq -e '(.data.apps | map(.name)) == ["Calculator","Kitty (mine)","Other group"] and (.data.apps[0].exec == "calc --flag % done") and (.data.apps[1].exec == "kitty --mine")' >/dev/null || fail "list: $(run "$binary" apps list --json)"
run "$binary" apps list | grep -q 'Kitty (mine)  (kitty.desktop)' || fail 'list text'
[[ "$(run "$binary" apps list --json | jq '[.data.apps[] | select(.name == "Firefox")] | length')" == 0 ]] || fail 'a Hidden=true entry in a later folder removes the app'

# the grid: choose Calculator (index 0) -> its Exec runs detached; the menu got the names (and icons where the provider takes them)
run "$binary" runner menu-set rofi >/dev/null
printf '0\n' > "$FAKE/answers"; run "$binary" apps || fail 'apps exits 0'
for _ in $(seq 1 20); do [[ -s "$FAKE/launch.log" ]] && break; sleep 0.2; done
grep -q '^launched --flag % done$' "$FAKE/launch.log" || fail "the app started with its Exec: $(cat "$FAKE/launch.log" 2>/dev/null)"
grep -q 'Calculator' "$FAKE/menu.in" && grep -q 'Kitty (mine)' "$FAKE/menu.in" || fail 'the menu lists the apps'
# cancelling starts nothing
rm -f "$FAKE/n" "$FAKE/launch.log"; : > "$FAKE/answers"; run "$binary" apps || fail 'cancel exits 0'; sleep 0.4
[[ ! -s "$FAKE/launch.log" ]] || fail 'a cancelled grid started something'
# nothing to show, or no menu program: exit 4
set +e; env HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_APPS_DIRS="$tmp/none" FAKE="$FAKE" PATH="$tmp/bin:$PATH" "$binary" apps >/dev/null 2>&1; rc=$?; set -e; [[ "$rc" == 4 ]] || fail "no apps exits 4 (got $rc)"
rm "$tmp/bin/rofi"; [[ "$(code "$binary" apps)" == 4 ]] || fail 'a missing menu program exits 4'
echo "apps-test: ok"

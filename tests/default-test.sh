#!/usr/bin/env bash
# `bxrig default browser|terminal|show` with fake xdg-settings and kwriteconfig6. Usage: default-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/apps" "$tmp/nobin"; export LOG="$tmp/log"; : > "$LOG"
printf '#!/usr/bin/env bash\necho "xdg-settings $*" >> "$LOG"\ncase "$1" in get) echo "firefox.desktop" ;; esac\n' > "$tmp/bin/xdg-settings"
chmod +x "$tmp/bin/xdg-settings"
run() { env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_STATE_HOME="$tmp/state" BXRIG_APPS_DIRS="$tmp/apps" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
d() { run "$binary" default "$@"; }

# browser
[[ "$(code "$binary" default browser firefox --yes)" == 4 ]] || fail 'a browser that is not installed exits 4'
touch "$tmp/apps/firefox.desktop" "$tmp/apps/brave-browser.desktop"
[[ "$(code "$binary" default browser firefox)" == 2 ]] || fail 'no --yes exits 2'
[[ ! -s "$LOG" ]] || fail 'the plan changed something'
d browser firefox --dry-run --json | jq -e '.ok and .dry_run and .data.desktop == "firefox.desktop"' >/dev/null || fail 'dry-run --json'
d browser firefox --yes | grep -q 'firefox is now your default web browser' || fail 'browser --yes'
grep -q 'xdg-settings set default-web-browser firefox.desktop' "$LOG" || fail "xdg-settings was not run: $(cat "$LOG")"
d browser brave --yes >/dev/null; grep -q 'default-web-browser brave-browser.desktop' "$LOG" || fail 'brave maps to brave-browser.desktop'
[[ "$(code "$binary" default browser zen --yes)" == 4 ]] || fail 'a browser without a known desktop entry exits 4'
[[ "$(code "$binary" default browser nope --yes)" == 4 ]] || fail 'an unknown browser exits 4'
PATH_BACKUP="$PATH"; rm "$tmp/bin/xdg-settings"
rc=0; env HOME="$tmp/home" BXRIG_APPS_DIRS="$tmp/apps" PATH="$tmp/nobin" "$binary" default browser firefox --yes >/dev/null 2>&1 || rc=$?; [[ "$rc" == 4 ]] || fail "no xdg-settings exits 4 (got $rc)"
printf '#!/usr/bin/env bash\necho "xdg-settings $*" >> "$LOG"\ncase "$1" in get) echo "firefox.desktop" ;; esac\n' > "$tmp/bin/xdg-settings"; chmod +x "$tmp/bin/xdg-settings"

# terminal
[[ "$(code "$binary" default terminal ghostty --yes)" == 4 ]] || fail 'a terminal that is not installed exits 4'
touch "$tmp/apps/com.mitchellh.ghostty.desktop" "$tmp/apps/kitty.desktop"
[[ "$(code "$binary" default terminal ghostty)" == 2 ]] || fail 'terminal without --yes exits 2'
[[ ! -e "$tmp/cfg/xdg-terminals.list" ]] || fail 'the plan wrote the terminal list'
d terminal ghostty --yes >/dev/null || fail 'terminal --yes'
[[ "$(cat "$tmp/cfg/xdg-terminals.list")" == 'com.mitchellh.ghostty.desktop' ]] || fail 'xdg-terminals.list names the desktop entry'
# changing it again is fine while the file is untouched; a file you edited is kept
d terminal kitty --yes >/dev/null; [[ "$(cat "$tmp/cfg/xdg-terminals.list")" == 'kitty.desktop' ]] || fail 'a clean file is updated'
echo '# mine' > "$tmp/cfg/xdg-terminals.list"
out="$(d terminal ghostty --yes)"; [[ "$out" == *'was changed by you, so it was kept'* && "$(cat "$tmp/cfg/xdg-terminals.list")" == '# mine' ]] || fail "an edited list is kept: $out"
[[ "$(code "$binary" default terminal putty --yes)" == 4 ]] || fail 'an unknown terminal exits 4'
# KDE's own setting when kwriteconfig6 is there
printf '#!/usr/bin/env bash\necho "kwriteconfig6 $*" >> "$LOG"\n' > "$tmp/bin/kwriteconfig6"; chmod +x "$tmp/bin/kwriteconfig6"; rm -f "$tmp/cfg/xdg-terminals.list"; : > "$LOG"
d terminal ghostty --yes >/dev/null
grep -q 'kwriteconfig6 --file kdeglobals --group General --key TerminalApplication ghostty' "$LOG" && grep -q 'key TerminalService com.mitchellh.ghostty.desktop' "$LOG" || fail "KDE setting: $(cat "$LOG")"

# show and usage
d show | grep -q 'Default browser:  firefox.desktop' || fail 'show'
[[ "$(code "$binary" default)" == 2 && "$(code "$binary" default bogus)" == 2 && "$(code "$binary" default browser)" == 2 ]] || fail 'usage exits 2'
: > "$LOG"
# file manager
printf '#!/usr/bin/env bash\necho "xdg-mime $*" >> "$LOG"\ncase "$1" in query) echo "org.kde.dolphin.desktop" ;; esac\n' > "$tmp/bin/xdg-mime"; chmod +x "$tmp/bin/xdg-mime"
[[ "$(code "$binary" default filemanager strata --yes)" == 4 ]] || fail 'a file manager that is not installed exits 4'
touch "$tmp/apps/io.github.lgse.Strata.desktop"
[[ "$(code "$binary" default filemanager strata)" == 2 ]] || fail 'filemanager without --yes exits 2'
d filemanager strata --yes | grep -q 'strata is now your default file manager' || fail 'filemanager --yes'
grep -q 'xdg-mime default io.github.lgse.Strata.desktop inode/directory' "$LOG" || fail "xdg-mime was not run: $(cat "$LOG")"
[[ "$(code "$binary" default filemanager nautilus --yes)" == 4 ]] || fail 'an unknown file manager exits 4'
d show --json | jq -e '.data.filemanager == "org.kde.dolphin.desktop"' >/dev/null || fail 'show reports the file manager'

echo "default tests passed"

#!/usr/bin/env bash
# `bxcachy dictation`, `quicklook` and `dolphin doctor` with fake tools. Usage: extras-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/xdg/menus"
printf '#!/usr/bin/env bash\nprintf "kio-extras\\nkdegraphics-thumbnailers\\nkimageformats\\nffmpegthumbs\\npolkit-kde-agent\\n"\n' > "$tmp/bin/pacman"
printf '#!/usr/bin/env bash\necho "xdg-mime $*" >> "$LOG"\ncase "$1" in query) echo "io.github.lgse.Strata.desktop" ;; esac\n' > "$tmp/bin/xdg-mime"
printf '#!/usr/bin/env bash\necho "kbuildsycoca6 $*" >> "$LOG"\n' > "$tmp/bin/kbuildsycoca6"
printf '#!/usr/bin/env bash\necho "superwhisper" >> "$LOG"\n' > "$tmp/bin/superwhisper"
chmod +x "$tmp/bin"/*; export LOG="$tmp/log"; : > "$LOG"
run() { env HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" XDG_CONFIG_DIRS="$tmp/xdg" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

# dictation: the engines, their shortcuts, status
run "$binary" dictation key | grep -q 'Hold Right Alt' || fail 'superwhisper shortcut'
run "$binary" dictation key voxtype | grep -q 'F9' || fail 'voxtype shortcut'
[[ "$(code "$binary" dictation key nope)" == 4 ]] || fail 'unknown engine exits 4'
run "$binary" dictation status --json | jq -e '(.data.engines | map(select(.installed)) | map(.engine)) == ["superwhisper"]' >/dev/null || fail 'status finds the installed engine'
[[ "$(code "$binary" dictation setup)" == 2 ]] || fail 'setup without --yes exits 2'
run "$binary" dictation setup voxtype --dry-run --json | jq -e '.dry_run != null and (.data.apps == ["voxtype","wtype"])' >/dev/null || run "$binary" dictation setup voxtype --dry-run | grep -q 'install voxtype, wtype' || fail 'setup voxtype dry run'

# quicklook
printf '#!/usr/bin/env bash\necho "kiview $*" >> "$LOG"\n' > "$tmp/bin/kiview"; chmod +x "$tmp/bin/kiview"
echo hi > "$tmp/file.txt"
run "$binary" quicklook "$tmp/file.txt" >/dev/null; grep -q "kiview -s $tmp/file.txt" "$LOG" || fail "kiview -s was not run: $(cat "$LOG")"
run "$binary" quicklook "$tmp" --dry-run | grep -q 'Dry run: kiview -s' || fail 'dry run'
[[ "$(code "$binary" quicklook "$tmp/missing")" == 4 ]] || fail 'a missing path exits 4'
rm "$tmp/bin/kiview"; [[ "$(code "$binary" quicklook "$tmp/file.txt")" == 4 ]] || fail 'no kiview exits 4'

# dolphin doctor: passes with everything in place, flags the missing menu file, --fix rebuilds the cache
: > "$LOG"; touch "$tmp/xdg/menus/plasma-applications.menu"
[[ "$(env XDG_MENU_PREFIX=plasma- HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" XDG_CONFIG_DIRS="$tmp/xdg" PATH="$tmp/bin:$PATH" LOG="$LOG" "$binary" dolphin doctor >/dev/null 2>&1; echo $?)" == 0 ]] || fail 'a healthy setup exits 0'
rm "$tmp/xdg/menus/plasma-applications.menu"
[[ "$(code "$binary" dolphin doctor)" == 4 ]] || fail 'a missing menu file exits 4'
{ run "$binary" dolphin doctor --json || true; } | jq -e '.data.checks | map(select(.ok | not)) | map(.id) | index("menu") != null' >/dev/null || fail 'doctor json lists menu'
touch "$tmp/xdg/menus/plasma-applications.menu"; run "$binary" dolphin doctor --fix >/dev/null || true
grep -q 'kbuildsycoca6 --noincremental' "$LOG" || fail '--fix rebuilds the cache'
echo "extras-test ok"

#!/usr/bin/env bash
# `bxcachy plasma panels|desktops` with fake qdbus6, kwriteconfig6 and dbus-send. Usage: plasma-panels-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/cfg"; export LOG="$tmp/log"; : > "$LOG"
printf '#!/usr/bin/env bash\necho "qdbus6 $1 $2 $3" >> "$LOG"\nif [ "$1" = org.kde.plasmashell ] && [ -z "${2:-}" ]; then [ "${RUNNING:-0}" = 1 ] && exit 0 || exit 1; fi\nif [ "${3:-}" = org.kde.PlasmaShell.evaluateScript ]; then printf "%%s" "$4" > "$tmp_script"; fi\n' > "$tmp/bin/qdbus6"
for t in kwriteconfig6 dbus-send; do printf '#!/usr/bin/env bash\necho "%s $*" >> "$LOG"\n' $t > "$tmp/bin/$t"; done
chmod +x "$tmp/bin"/*
export tmp_script="$tmp/script.js"
run() { env HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" PATH="$tmp/bin:$PATH" LOG="$LOG" tmp_script="$tmp_script" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
echo '[Containments][1]' > "$tmp/cfg/plasma-org.kde.plasma.desktop-appletsrc"

# plan and dry run change nothing
[[ "$(code "$binary" plasma panels apply)" == 2 ]] || fail 'apply without --yes exits 2'
run "$binary" plasma panels apply --dry-run | grep -q 'kickoff pager | windowtitle' || fail 'dry run shows the widget order'
[[ ! -d "$tmp/cfg/bxcachy/plasma-panels" ]] || fail 'a dry run wrote something'
run "$binary" plasma panels apply --dry-run --json | jq -e '.data.widgets[0] == "org.kde.plasma.kickoff" and (.data.widgets | index("org.kde.plasma.weather") != null) and .data.desktops == 4' >/dev/null || fail 'dry run json'

# Plasma not running: the script is saved, a one-time autostart entry is queued, the old layout is backed up, desktops are set to 4
run "$binary" plasma panels apply --yes | grep -q 'next Plasma login' || fail 'queued message'
[[ -f "$tmp/cfg/bxcachy/plasma-panels/layout.js" && -f "$tmp/cfg/autostart/bxcachy-plasma-panels.desktop" ]] || fail 'layout and autostart entry'
grep -q 'bxcachy plasma panels apply --yes --preset=Rounded-Widgets' "$tmp/cfg/autostart/bxcachy-plasma-panels.desktop" || fail 'autostart command'
grep -q '^\[Containments\]\[1\]' "$tmp/cfg/bxcachy/plasma-panels/backup/plasma-org.kde.plasma.desktop-appletsrc" || fail 'backup of the old layout'
grep -q 'kwriteconfig6 --file kwinrc --group Desktops --key Number 4' "$LOG" || fail 'four virtual desktops'
js="$tmp/cfg/bxcachy/plasma-panels/layout.js"
for id in org.kde.plasma.kickoff org.kde.plasma.pager org.kde.windowtitle org.kde.plasma.digitalclock org.kde.plasma.weather org.kde.plasma.mediacontroller org.kde.plasma.kvitals org.kde.plasma.systemtray luisbocanegra.panel.colorizer org.kde.plasma.icontasks; do grep -q "\"$id\"" "$js" || fail "layout lacks $id"; done
ord="$(grep -o 'addWidget("[a-z.A-Z]*")' "$js" | sed 's/addWidget("//; s/")//' | tr '\n' ' ')"
[[ "$ord" == *"kickoff org.kde.plasma.pager luisbocanegra.panel.colorizer.islands.separator org.kde.windowtitle org.kde.plasma.panelspacer luisbocanegra.panel.colorizer.islands.separator org.kde.plasma.digitalclock"* ]] || fail "widget order: $ord"
grep -q 'islandsEnabled", true' "$js" || fail 'islands are switched on'
grep -q 'location = "top"' "$js" && grep -q 'location = "bottom"' "$js" || fail 'two panels'
run "$binary" plasma panels status --json | jq -e '.data.queued and .data.layout_saved and .data.backup' >/dev/null || fail 'status'

# Plasma running: the script goes to evaluateScript, the preset is applied, the queued entry is removed; the first backup is kept
echo '[Containments][2]' > "$tmp/cfg/plasma-org.kde.plasma.desktop-appletsrc"
: > "$LOG"; RUNNING=1 run "$binary" plasma panels apply --yes --agenda --without-weather | tee "$tmp/out" | grep -q applied || fail "applied now: $(cat "$tmp/out")"
grep -q 'org.kde.PlasmaShell.evaluateScript' "$LOG" || fail 'evaluateScript was not called'
grep -q 'dbus-send --session --type=signal /preset luisbocanegra.panel.colorizer.all.preset string:/usr/share/plasma/plasmoids/luisbocanegra.panel.colorizer/contents/ui/presets/Rounded Widgets' "$LOG" || fail 'preset signal'
[[ ! -f "$tmp/cfg/autostart/bxcachy-plasma-panels.desktop" ]] || fail 'the queued entry was not removed'
grep -q 'org.kde.plasma.eventcalendar' "$js" && ! grep -q 'org.kde.plasma.weather' "$js" && ! grep -q 'org.kde.plasma.digitalclock' "$js" || fail '--agenda and --without-weather'
grep -q '^\[Containments\]\[1\]' "$tmp/cfg/bxcachy/plasma-panels/backup/plasma-org.kde.plasma.desktop-appletsrc" || fail 'the first backup was overwritten'

# undo restores the first backup
[[ "$(code "$binary" plasma panels undo)" == 2 ]] || fail 'undo without --yes exits 2'
run "$binary" plasma panels undo --yes | grep -q 'back' || fail 'undo'
grep -q '^\[Containments\]\[1\]' "$tmp/cfg/plasma-org.kde.plasma.desktop-appletsrc" || fail 'the old layout was not restored'
rm -rf "$tmp/cfg/bxcachy"; [[ "$(code "$binary" plasma panels undo --yes)" == 4 ]] || fail 'undo without a backup exits 4'

# desktops
: > "$LOG"; run "$binary" plasma desktops 3 --yes >/dev/null; grep -q 'Number 3' "$LOG" && grep -q 'Rows 1' "$LOG" || fail 'plasma desktops'
[[ "$(code "$binary" plasma desktops 0 --yes)" == 4 ]] || fail 'bad count exits 4'
[[ "$(code "$binary" plasma)" == 2 ]] || fail 'usage exits 2'
echo "plasma-panels-test ok"

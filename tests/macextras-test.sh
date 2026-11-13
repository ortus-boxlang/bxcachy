#!/usr/bin/env bash
# emoji, forcequit, window, overview, nightshift, gpu doctor, input, airplay and settings export/import with fake tools. Usage: macextras-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/nobin" "$tmp/zi" "$tmp/cfg/bxcachy"; export LOG="$tmp/log"; : > "$LOG"
logger() { printf '#!/usr/bin/env bash\necho "%s $*" >> "$LOG"\n%s\n' "$1" "${2:-}" > "$tmp/bin/$1"; }
for t in rofimoji hyprctl qdbus6 wlsunset systemctl kwriteconfig6 libinput-gestures-setup libinput-gestures uxplay hyprpm; do logger $t; done
logger timedatectl 'echo Europe/Madrid'
logger lspci 'printf "00:02.0 VGA compatible controller [0300]: Intel Corporation UHD [8086:9a49]\n01:00.0 3D controller [0302]: NVIDIA Corporation GA107 [10de:25a2]\n"'
logger pacman 'printf "mesa\nnvidia-utils\n"'
logger id 'echo "ada wheel"'
chmod +x "$tmp/bin"/*
printf '#country\tcoords\ttz\n#\nES\t+4024-00341\tEurope/Madrid\tmain\n' > "$tmp/zi/zone1970.tab"
run() { env HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_ZONEINFO="$tmp/zi" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
nobin() { env HOME="$tmp/home" PATH="$tmp/nobin" "$@"; }

run "$binary" emoji; grep -q '^rofimoji' "$LOG" || fail 'emoji'
run "$binary" forcequit; grep -q '^hyprctl kill' "$LOG" || fail 'forcequit on Hyprland'
BXCACHY_DESKTOP=KDE run "$binary" forcequit; grep -q 'qdbus6 org.kde.KWin /KWin org.kde.KWin.killWindow' "$LOG" || fail 'forcequit on Plasma'
run "$binary" window minimize; grep -q 'hyprctl dispatch movetoworkspacesilent special:minimized' "$LOG" || fail 'minimize'
run "$binary" window restore; grep -q 'hyprctl dispatch togglespecialworkspace minimized' "$LOG" || fail 'restore'
run "$binary" overview; grep -q 'hyprctl dispatch hyprexpo:expo toggle' "$LOG" || fail 'overview'
BXCACHY_DESKTOP=KDE run "$binary" overview; grep -q 'invokeShortcut Overview' "$LOG" || fail 'plasma overview'
run "$binary" overview setup >/dev/null; grep -q 'hyprpm enable hyprexpo' "$LOG" || fail 'overview setup'
rc=0; nobin "$binary" emoji >/dev/null 2>&1 || rc=$?; [[ "$rc" == 4 ]] || fail "no rofimoji exits 4 (got $rc)"

# night shift: coordinates from the time zone (40°24' N, 3°41' W = 40.4, -3.68), a user service, on and off
: > "$LOG"; run "$binary" nightshift on --json | jq -e '.data.active and .data.latitude == 40.4 and .data.longitude == -3.68' >/dev/null || fail "nightshift coordinates: $(run "$binary" nightshift on --json)"
grep -q 'ExecStart=wlsunset -l 40.4 -L -3.68' "$tmp/cfg/systemd/user/bxcachy-wlsunset.service" || fail 'unit'
grep -q 'systemctl --user enable --now bxcachy-wlsunset.service' "$LOG" || fail 'enable'
run "$binary" nightshift on --location=10,20 >/dev/null; grep -q 'ExecStart=wlsunset -l 10 -L 20' "$tmp/cfg/systemd/user/bxcachy-wlsunset.service" || fail 'a new location rewrites the unit we wrote'
echo '# mine' >> "$tmp/cfg/systemd/user/bxcachy-wlsunset.service"; run "$binary" nightshift on --location=1,2 >/dev/null; grep -q '^# mine' "$tmp/cfg/systemd/user/bxcachy-wlsunset.service" || fail 'an edited unit is kept'
run "$binary" nightshift off >/dev/null; grep -q 'disable --now bxcachy-wlsunset.service' "$LOG" || fail 'off'
[[ "$(code "$binary" nightshift on --location=abc)" == 4 ]] || fail 'bad location exits 4'
: > "$LOG"; BXCACHY_DESKTOP=KDE run "$binary" nightshift on >/dev/null; grep -q 'kwriteconfig6 --file kwinrc --group NightColor --key Active true' "$LOG" && grep -q 'Mode Automatic' "$LOG" || fail 'plasma night light'

# GPU: vendors and missing packages
{ run "$binary" gpu doctor --json || true; } | jq -e '(.data.vendors | index("nvidia") != null) and (.data.vendors | index("intel") != null) and (.data.missing | index("libva-nvidia-driver") != null)' >/dev/null || fail "gpu: $(run "$binary" gpu doctor --json)"
{ run "$binary" gpu doctor || true; } | grep -q 'ollama-cuda' || fail 'gpu note for local AI'
[[ "$(code "$binary" gpu doctor)" == 4 ]] || fail 'missing packages exit 4'

# input: doctor and gestures
run "$binary" input doctor --json | jq -e '.data.libinput_gestures == true and .data.in_input_group == false' >/dev/null || fail 'input doctor'
[[ "$(code "$binary" input gestures)" == 2 ]] || fail 'gestures without --yes exits 2'
: > "$LOG"; run "$binary" input gestures --yes >/dev/null; grep -q 'gesture swipe left 3 hyprctl dispatch workspace e+1' "$tmp/cfg/libinput-gestures.conf" || fail 'gestures file'
grep -q 'libinput-gestures-setup autostart' "$LOG" && grep -q 'libinput-gestures-setup start' "$LOG" || fail 'gestures autostart'

# airplay
: > "$LOG"; run "$binary" airplay on >/dev/null; grep -q 'ExecStart=uxplay -n BxCachy' "$tmp/cfg/systemd/user/bxcachy-airplay.service" || fail 'airplay unit'
run "$binary" airplay off >/dev/null; grep -q 'disable --now bxcachy-airplay.service' "$LOG" || fail 'airplay off'

# settings export and import
echo '{"desktops":"hyprland"}' > "$tmp/cfg/bxcachy/answers.json"; echo '{"x":1}' > "$tmp/cfg/bxcachy/shortcuts.json"; echo 'secret' > "$tmp/cfg/bxcachy/secrets.env"; mkdir -p "$tmp/cfg/bxcachy/backups"; echo b > "$tmp/cfg/bxcachy/backups/old"
run "$binary" settings export "$tmp/s.tgz" --json | jq -e '(.data.files | index("bxcachy/answers.json") != null) and (.data.files | index("bxcachy/shortcuts.json") != null) and (.data.files | map(select(test("secret|backup"))) | length) == 0' >/dev/null || fail "export: $(run "$binary" settings export "$tmp/s2.tgz" --json)"
[[ "$(code "$binary" settings export "$tmp/s.tgz")" == 4 ]] || fail 'export will not overwrite'
echo '{"desktops":"plasma"}' > "$tmp/cfg/bxcachy/answers.json"
[[ "$(code "$binary" settings import "$tmp/s.tgz")" == 2 ]] || fail 'import without --yes exits 2'
run "$binary" settings import "$tmp/s.tgz" --yes | grep -q 'Imported' || fail 'import'
grep -q hyprland "$tmp/cfg/bxcachy/answers.json" || fail 'the imported answers'
ls "$tmp/cfg/bxcachy" | grep -q 'answers.json.bak-' || fail 'the existing file was backed up'
mkdir -p "$tmp/evil/bxcachy"; echo x > "$tmp/evil/escape"; tar -czf "$tmp/evil.tgz" -C "$tmp/evil" escape 2>/dev/null
[[ "$(code "$binary" settings import "$tmp/evil.tgz" --yes)" == 4 ]] || fail 'an archive outside bxcachy/ is refused'
echo "macextras-test ok"

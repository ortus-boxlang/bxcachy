#!/usr/bin/env bash
# `bxcachy web add|list|rm` and `bxcachy vpn nordvpn setup` with fake browsers, xdg-settings, sudo and systemctl. Usage: web-vpn-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/data"; export LOG="$tmp/log"; : > "$LOG"
for b in brave chromium firefox; do printf '#!/usr/bin/env bash\n' > "$tmp/bin/$b"; done
printf '#!/usr/bin/env bash\necho "${DEFAULT_BROWSER:-firefox.desktop}"\n' > "$tmp/bin/xdg-settings"
printf '#!/usr/bin/env bash\necho "sudo $*" >> "$LOG"\n' > "$tmp/bin/sudo"
printf '#!/usr/bin/env bash\n' > "$tmp/bin/nordvpn"
chmod +x "$tmp/bin"/*
run() { env HOME="$tmp/home" USER=ada XDG_DATA_HOME="$tmp/data" BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_STATE_HOME="$tmp/state" DEFAULT_BROWSER="${DEFAULT_BROWSER:-firefox.desktop}" LOG="$LOG" PATH="$tmp/bin:$PATH" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
f="$tmp/data/applications/bxcachy-web-notion.desktop"

# validation and plan
[[ "$(code "$binary" web add 'no way' https://notion.so --yes)" == 4 ]] || fail 'a bad name exits 4'
[[ "$(code "$binary" web add notion notion.so --yes)" == 4 ]] || fail 'a URL needs a scheme'
[[ "$(code "$binary" web add notion 'https://x.com/"; rm' --yes)" == 4 ]] || fail 'a URL with quotes is refused'
[[ "$(code "$binary" web add notion https://www.notion.so --browser=lynx --yes)" == 4 ]] || fail 'an unknown browser exits 4'
[[ "$(code "$binary" web add notion https://www.notion.so)" == 2 ]] || fail 'no --yes exits 2'
[[ ! -e "$f" ]] || fail 'the plan wrote a file'

# the default browser (firefox here) has no app mode; a chromium-family browser given gets --app=
DEFAULT_BROWSER=firefox.desktop run "$binary" web add notion https://www.notion.so --yes --json | jq -e '.data.browser == "firefox" and .data.app_mode == false' >/dev/null || fail 'firefox default'
grep -q '^Exec=firefox --new-window https://www.notion.so$' "$f" || fail "firefox exec: $(cat "$f")"
run "$binary" web rm notion --yes >/dev/null
run "$binary" web add notion https://www.notion.so --browser=brave --yes | grep -q 'Added notion' || fail 'add --yes'
grep -q '^Exec=brave --app=https://www.notion.so$' "$f" && grep -q '^Name=notion$' "$f" && grep -q '^Type=Application$' "$f" || fail "desktop entry: $(cat "$f")"
DEFAULT_BROWSER=chromium.desktop run "$binary" web add docs https://docs.example.com --yes --json | jq -e '.data.browser == "chromium" and .data.app_mode == true' >/dev/null || fail 'the default browser is used when it is installed'
run "$binary" web list --json | jq -e '(.data.apps | map(.name) | sort) == ["docs","notion"] and (.data.apps[] | select(.name=="notion") | .url == "https://www.notion.so")' >/dev/null || fail 'list'

# idempotent; a file you edited is kept
run "$binary" web add notion https://www.notion.so --browser=brave --yes | grep -q 'Added' || fail 'adding the same app again is fine'
echo '# mine' >> "$f"
[[ "$(code "$binary" web add notion https://other.example --browser=brave --yes)" == 4 ]] || fail 'a changed entry is kept (exit 4)'
grep -q '# mine' "$f" || fail 'the changed entry was overwritten'

# web add with no arguments asks on the terminal (a file plays the three answers: name, URL, browser)
printf 'Docs\nhttps://docs.example.com\nbrave\n' > "$tmp/answers"
BXCACHY_TTY_IN="$tmp/answers" run "$binary" web add --json | jq -e '.data.name == "Docs" and .data.url == "https://docs.example.com" and .data.browser == "brave"' >/dev/null || fail "interactive web add: $(BXCACHY_TTY_IN="$tmp/answers" run "$binary" web add --json 2>&1)"
grep -q '^Exec=brave --app=https://docs.example.com$' "$tmp/data/applications/bxcachy-web-Docs.desktop" || fail 'interactive entry'
run "$binary" web rm Docs --yes >/dev/null
printf '\n\n\n' > "$tmp/answers"; set +e; BXCACHY_TTY_IN="$tmp/answers" run "$binary" web add >/dev/null 2>&1; rc=$?; set -e; [[ "$rc" == 4 ]] || fail 'empty answers exit 4'

# rm
[[ "$(code "$binary" web rm notion)" == 2 ]] || fail 'rm without --yes exits 2'
[[ -e "$f" ]] || fail 'the rm plan deleted it'
run "$binary" web rm notion --yes | grep -q 'removed' || fail 'rm --yes'
[[ ! -e "$f" ]] || fail 'rm did not delete'
[[ "$(code "$binary" web rm notion --yes)" == 4 ]] || fail 'rm of a missing app exits 4'
mkdir -p "$tmp/nobin"; ln -sf "$(command -v sh)" "$tmp/nobin/sh"
set +e; env HOME="$tmp/home" XDG_DATA_HOME="$tmp/data" PATH="$tmp/nobin" "$binary" web add x https://x.example --yes >/dev/null 2>&1; rc=$?; set -e; [[ "$rc" == 4 ]] || fail "no browser exits 4 (got $rc)"

# ---- vpn ----
[[ "$(code "$binary" vpn nordvpn setup)" == 2 ]] || fail 'vpn setup without --yes exits 2'
[[ ! -s "$LOG" ]] || fail 'the vpn plan ran something'
run "$binary" vpn nordvpn setup --yes | grep -q 'nordvpn login' || fail 'vpn setup --yes'
grep -q 'sudo systemctl enable --now nordvpnd' "$LOG" && grep -q 'sudo gpasswd -a ada nordvpn' "$LOG" || fail "vpn commands: $(cat "$LOG")"
rm "$tmp/bin/nordvpn"; [[ "$(code "$binary" vpn nordvpn setup --yes)" == 4 ]] || fail 'NordVPN missing exits 4'
echo "web-vpn-test: ok"

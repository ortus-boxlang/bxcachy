#!/usr/bin/env bash
# `bxrig tui` outside a terminal: page data as JSON, demo data, usage and unknown pages. Usage: tui-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
export HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_STATE_HOME="$tmp/state" BXRIG_SELF="$binary"
mkdir -p "$HOME"
code() { set +e; "$@" >/dev/null 2>&1; echo $?; set -e; }

# demo data: made-up, fully described, two things to look at
"$binary" tui dashboard --demo --json | jq -e '.ok and .data.data.host == "orion" and (.data.attention | length == 2) and (.data.data.machines | length == 4) and (.data.data.backups | length == 3)' >/dev/null || fail 'demo dashboard json'
"$binary" tui --demo --json | jq -e '.data.attention[0].action.args == ["system","update"]' >/dev/null || fail 'default page is the dashboard'

# the other pages in demo mode
"$binary" tui ports --demo --json | jq -e '.data.rows == 7 and (.data.items | map(select(.conflict)) | length == 2)' >/dev/null || fail 'ports demo'
"$binary" tui java --demo --json | jq -e '.data.items[0].id == "temurin-21.0.13_9"' >/dev/null || fail 'java demo'
for pg in boxlang maven gradle versions shortcuts machines databases mail storage secrets themes logs; do "$binary" tui "$pg" --demo --json | jq -e '.ok and (.data.rows > 0)' >/dev/null || fail "$pg demo"; done
"$binary" tui packages --demo --json | jq -e '.data.rows == 0' >/dev/null || fail 'packages start empty until you search'

# the real machine: never fails, has the parts (power switch points at an empty folder: no battery)
mkdir -p "$tmp/power"
BXRIG_POWER_DIR="$tmp/power" "$binary" tui dashboard --json | jq -e '.ok and (.data.data.mem.total > 0) and (.data.data.battery.present == false) and (.data.data.backups | type == "array") and (.data.data.os | length > 0)' >/dev/null || fail 'real dashboard json'

# a battery shows up and a low one is an error
mkdir -p "$tmp/power/BAT0"; echo Battery > "$tmp/power/BAT0/type"; echo 12 > "$tmp/power/BAT0/capacity"; echo Discharging > "$tmp/power/BAT0/status"
BXRIG_POWER_DIR="$tmp/power" "$binary" tui dashboard --json | jq -e '.data.data.battery.percent == 12 and (.data.attention | map(select(.level == "error" and (.text | test("Battery at 12")))) | length == 1)' >/dev/null || fail 'low battery'

# a forced data file replaces the machine
echo '{"host":"x","os":"Test","kernel":"1","uptime":60,"cpu":0.1,"mem":{"used":1,"total":2},"disk":{"used":1,"total":2},"battery":{"present":false,"percent":0,"charging":false},"updates":0,"machines":[],"backups":[],"now":1000}' > "$tmp/d.json"
BXRIG_DASHBOARD_FILE="$tmp/d.json" "$binary" tui dashboard --json | jq -e '.data.data.host == "x" and (.data.attention | length == 0)' >/dev/null || fail 'forced data'

# tui list: every page with its title and icon name, one registry for the menu, the launchers and the shortcuts
"$binary" tui list --json | jq -e '.ok and (.data.pages | length == 16) and .data.pages[0].id == "dashboard" and (.data.pages | map(select(.id == "databases")) | .[0].title == "Databases") and all(.data.pages[]; (.icon | length) > 0)' >/dev/null || fail 'tui list --json'
"$binary" tui list | grep -q '^databases  Databases$' || fail 'tui list text'
for pg in $("$binary" tui list --json | jq -r '.data.pages[].id'); do "$binary" tui "$pg" --demo --json >/dev/null || fail "tui $pg --json from the list"; done
[[ "$(code "$binary" tui list --json)" == 0 ]] || fail 'tui list exits 0'
[[ "$(code "$binary" tui list extra)" == 2 ]] || fail 'tui list with more words exits 2'
[[ "$(code "$binary" tui databases --sidebar --json --demo)" == 0 ]] || fail '--sidebar is a known flag'
[[ "$(code "$binary" tui databases --no-sidebar --json --demo)" == 0 ]] || fail '--no-sidebar is a known flag'
# an unknown page names the pages and exits 2
out="$("$binary" tui nope 2>&1 || true)"; [[ "$out" == *"Pages: dashboard, boxlang"* ]] || fail 'unknown page lists the pages'

# the sidebar in a real pseudo-terminal: the Control Center opens it, a page alone collapses it, the flags and a narrow terminal decide
if command -v python3 >/dev/null; then
  frame() { python3 "$(dirname "$0")/pty-frame.py" "$binary" "$@"; }
  frame 120 38 tui --demo | grep -q 'tab  next page' || fail 'tui opens the sidebar'
  [[ -z "$(frame 120 38 tui databases --demo | grep 'tab  next page')" ]] || fail 'tui PAGE starts collapsed'
  frame 120 38 tui databases --demo | grep -q 'Databases' || fail 'tui PAGE shows the page'
  frame 120 38 tui databases --sidebar --demo | grep -q 'tab  next page' || fail '--sidebar opens it on a page'
  [[ -z "$(frame 120 38 tui --no-sidebar --demo | grep 'tab  next page')" ]] || fail '--no-sidebar collapses the Control Center'
  [[ -z "$(frame 80 30 tui --demo | grep 'tab  next page')" ]] || fail 'a narrow terminal starts collapsed'
  frame 80 30 tui --sidebar --demo | grep -q 'tab  next page' || fail '--sidebar wins on a narrow terminal'
fi

# usage and unknown pages
[[ "$(code "$binary" tui nope --json)" == 2 ]] || fail 'unknown page exits 2'
[[ "$(code "$binary" tui a b)" == 2 ]] || fail 'too many words exit 2'
echo "tui tests passed"

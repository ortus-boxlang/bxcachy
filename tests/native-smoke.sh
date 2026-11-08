#!/usr/bin/env bash
set -euo pipefail
binary="${1:-./bxcachy}"
test -x "$binary"
"$binary" version | grep -F 'BxCachy 0.11.0-dev'
"$binary" doctor | grep -F 'Java 21'
"$binary" plan | grep -F 'localsend'
"$binary" desktop-list | grep -F 'obs-studio'
"$binary" tui-list | grep -F 'lazygit'
"$binary" web-list | grep -F 'github.com'
"$binary" optional-list | grep -F 'optional'
"$binary" dev-plan | grep -F 'jdk21-openjdk'
"$binary" install | grep -F 'not yet implemented'

"$binary" optional-plan obs chromium | grep -F 'obs-studio'
"$binary" optional-plan obs chromium | grep -F 'chromium'
"$binary" optional-plan invalid | grep -F 'Unknown optional application'
"$binary" optional-plan | grep -F 'Usage:'
"$binary" help | grep -F 'optional-plan'

"$binary" profile-list | grep -F 'containers: podman'
"$binary" profile-plan jvm | grep -F 'jdk21-openjdk'
"$binary" profile-plan terminal | grep -F 'lazygit'
"$binary" profile-plan invalid | grep -F 'Unknown profile'
"$binary" profile-plan | grep -F 'Usage:'

"$binary" profile-install jvm --yes | grep -F 'no changes made'
"$binary" optional-install obs --yes | grep -F 'no changes made'
"$binary" help | grep -F 'profile-install'

"$binary" install-plan | grep -F 'pacseek'
"$binary" install-plan | grep -F 'No packages installed'
"$binary" profile-install-plan jvm | grep -F 'jdk21-openjdk maven gradle'
"$binary" profile-install-plan invalid | grep -F 'Unknown profile'
"$binary" profile-install-plan | grep -F 'Usage:'
"$binary" help | grep -F 'profile-install-plan'

# Package status must reject unsafe names before spawning pacman.
if "$binary" package-status 'bad;name' >/dev/null 2>&1; then
  echo 'FAIL: unsafe package name accepted' >&2
  exit 1
fi
status_output=""
if status_output="$("$binary" package-status 'bad;name' 2>&1)"; then
  echo 'FAIL: unsafe package-status name unexpectedly succeeded' >&2
  exit 1
else
  status_code=$?
fi
[[ "$status_code" -eq 2 ]] || { echo "FAIL: expected exit 2, got $status_code" >&2; exit 1; }
grep -F 'Usage:' <<< "$status_output"

# Invalid names must fail before repository tools are invoked.
if "$binary" package-source 'bad;name' >/dev/null 2>&1; then
  echo 'FAIL: unsafe repository lookup accepted' >&2
  exit 1
fi
source_output=""
if source_output="$("$binary" package-source 'bad;name' 2>&1)"; then
  echo 'FAIL: unsafe package-source name unexpectedly succeeded' >&2
  exit 1
else
  source_code=$?
fi
[[ "$source_code" -eq 2 ]] || { echo "FAIL: expected exit 2, got $source_code" >&2; exit 1; }
grep -F 'Usage:' <<< "$source_output"
"$binary" help | grep -F 'package-source'

#!/usr/bin/env bash
set -euo pipefail
binary="${1:-./bxcachy}"
test -x "$binary"
"$binary" version | grep -F 'BxCachy 0.11.0-dev'
"$binary" doctor | grep -F 'Java 21'
has() { grep -Fq -- "$1"; }
usage_exit2() { local out rc=0; out="$("$@" 2>&1)" || rc=$?; [[ "$rc" -eq 2 ]] || { echo "FAIL: $* exited $rc, wanted 2" >&2; exit 1; }; grep -Fq 'Usage:' <<<"$out" || { echo "FAIL: $*: no usage text" >&2; exit 1; }; }
expect_error() { local needle="$1"; shift; local out rc=0; out="$("$@" 2>&1)" || rc=$?; [[ "$rc" -eq 2 ]] || { echo "FAIL: $* exited $rc, wanted 2" >&2; exit 1; }; grep -Fq -- "$needle" <<<"$out" || { echo "FAIL: $*: missing '$needle'" >&2; exit 1; }; }
"$binary" plan | has 'Plan (default tier'
"$binary" plan | has 'neovim  [pacman]'
"$binary" desktop-list | has 'Visual Studio Code'
"$binary" tui-list | has 'lazygit'
"$binary" web-list | has 'boxlang-docs'
"$binary" optional-list | has '[optional]'
"$binary" dev-plan | has 'jdk21-openjdk'
if "$binary" install >/dev/null 2>&1; then echo 'FAIL: unconfirmed install accepted' >&2; exit 1; fi

"$binary" optional-plan obs chromium | has 'obs  ['
"$binary" optional-plan obs chromium | has 'chromium  ['
expect_error 'unknown app invalid' "$binary" optional-plan invalid
usage_exit2 "$binary" optional-plan
"$binary" help | has 'optional-plan'

"$binary" profile-list | has 'containers: Containers'
"$binary" profile-plan jvm | has 'maven'
"$binary" profile-plan terminal | has 'lazygit'
expect_error 'unknown profile invalid' "$binary" profile-plan invalid
usage_exit2 "$binary" profile-plan

if "$binary" profile-install jvm >/dev/null 2>&1; then echo 'FAIL: unconfirmed profile install accepted' >&2; exit 1; fi
if "$binary" optional-install invalid --yes >/dev/null 2>&1; then echo 'FAIL: invalid optional package accepted' >&2; exit 1; fi
"$binary" help | has 'profile-install'

"$binary" install-plan | has 'neovim'
"$binary" install-plan | has 'nothing was installed'
"$binary" profile-install-plan jvm | has 'maven'
expect_error 'unknown profile invalid' "$binary" profile-install-plan invalid
usage_exit2 "$binary" profile-install-plan
"$binary" help | has 'profile-install-plan'

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

echo 'Checking invalid profile-install rejection'
profile_output=""
if profile_output="$("$binary" profile-install invalid --yes 2>&1)"; then
  echo "FAIL: invalid profile accepted: $profile_output" >&2
  exit 1
else
  profile_code=$?
  echo "Invalid profile rejected with exit $profile_code: $profile_output"
fi
[[ "$profile_code" -eq 2 ]] || { echo "FAIL: invalid profile returned $profile_code instead of 2" >&2; exit 1; }
echo 'native smoke tests passed'

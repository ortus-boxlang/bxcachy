#!/usr/bin/env bash
# `bxcachy sdk` and Java through SDKMAN, with a fake SDKMAN and a local copy of its version API. Usage: sdk-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; srv=""; trap '[[ -n "$srv" ]] && kill "$srv" 2>/dev/null; rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
export HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_STATE_HOME="$tmp/state" BXCACHY_SDKMAN_DIR="$tmp/sdkman" BXCACHY_JAVA_DIR="$tmp/data/java" BXCACHY_JAVA_SYSTEM_DIR="$tmp/jvm" LOG="$tmp/log"
mkdir -p "$HOME"; : > "$LOG"
code() { set +e; "$@" >/dev/null 2>&1; echo $?; set -e; }

# the version API, served locally (the real one answers the same paths)
mkdir -p "$tmp/api/candidates/java/linuxx64/versions" "$tmp/api/candidates/maven/linuxx64/versions" "$tmp/api/candidates/default"
cat > "$tmp/api/candidates/java/linuxx64/versions/list" <<'F'
================================================================================
Available Java Versions for Linux 64bit
================================================================================
 Vendor         | Use | Version            | Identifier
--------------------------------------------------------------------------------
 Corretto       |     | 21.0.13.0+10       | 21.0.13.0+10-amzn
                |     | 17.0.21.0+10       | 17.0.21.0+10-amzn
 Temurin        |     | 25.0.5.0+8         | 25.0.5.0+8-tem
                |     | 21.0.13.0+9        | 21.0.13.0+9-tem
                |     | 17.0.21.0+9        | 17.0.21.0+9-tem
================================================================================
Omit Identifier to install default version 25.0.5.0+8-tem:
    $ sdk install java
F
cat > "$tmp/api/candidates/maven/linuxx64/versions/list" <<'F'
================================================================================
Available Maven Versions
================================================================================
     4.0.0-rc-7          3.9.7               3.8.2               3.2.2          
     3.10.0              3.9.6               3.8.1               3.2.1          
     3.9.16                                                                     
================================================================================
+ - local version
F
echo 3.10.0 > "$tmp/api/candidates/default/maven"
(cd "$tmp/api" && exec python3 -m http.server 0 --bind 127.0.0.1 >"$tmp/srv.log" 2>&1) & srv=$!
for _ in $(seq 1 50); do port="$(grep -o 'port [0-9]*' "$tmp/srv.log" 2>/dev/null | head -1 | grep -o '[0-9]*' || true)"; [[ -n "${port:-}" ]] && break; sleep 0.1; done
[[ -n "${port:-}" ]] || { # older python prints "Serving HTTP on 127.0.0.1 port N"; wait a little more
  sleep 1; port="$(grep -o 'port [0-9]*' "$tmp/srv.log" | head -1 | grep -o '[0-9]*')"; }
export BXCACHY_SDKMAN_API="http://127.0.0.1:$port"

# a fake installer that creates a fake SDKMAN with a `sdk` function
cat > "$tmp/installer.sh" <<'F'
mkdir -p "$SDKMAN_DIR/bin" "$SDKMAN_DIR/candidates"
cat > "$SDKMAN_DIR/bin/sdkman-init.sh" <<'G'
SDKMAN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sdk() {
  echo "sdk $*" >> "$LOG"
  local d="$SDKMAN_DIR/candidates/$2/$3"
  case "$1" in
    install) mkdir -p "$d/bin"; if [[ "$2" == java ]]; then printf 'JAVA_VERSION="%s"\nIMPLEMENTOR="Eclipse Adoptium"\n' "${3%%.*}.0.0" > "$d/release"; printf '#!/bin/sh\n' > "$d/bin/java"; chmod +x "$d/bin/java"; fi
             [[ -e "$SDKMAN_DIR/candidates/$2/current" ]] || ln -s "$d" "$SDKMAN_DIR/candidates/$2/current" ;;
    default) ln -sfn "$d" "$SDKMAN_DIR/candidates/$2/current" ;;
    uninstall) rm -rf "$d" ;;
  esac
}
G
F
export BXCACHY_SDKMAN_INSTALLER="file://$tmp/installer.sh"

# status and setup
"$binary" sdk status --json | jq -e '.data.installed == false and (.data.candidates.maven.versions | length == 0)' >/dev/null || fail 'status before setup'
[[ "$(code "$binary" sdk install maven 3.9.9 --yes)" == 4 ]] || fail 'install without SDKMAN exits 4'
[[ "$(code "$binary" sdk setup)" == 2 ]] || fail 'setup plan exits 2'
[[ ! -d "$tmp/sdkman" ]] || fail 'plan changed nothing'
"$binary" sdk setup --dry-run --json | jq -e '.dry_run' >/dev/null || fail 'setup dry run'
"$binary" sdk setup --yes >/dev/null
[[ -f "$tmp/sdkman/bin/sdkman-init.sh" ]] || fail 'setup installed SDKMAN'
grep -q 'MAVEN_HOME' "$tmp/cfg/bxcachy/sdk.sh" && grep -q 'fish_add_path' "$tmp/cfg/bxcachy/sdk.fish" || fail 'shell env files'
! grep -q 'JAVA_HOME' "$tmp/cfg/bxcachy/sdk.sh" || fail 'Java stays with bxcachy java default'
"$binary" sdk setup --yes --json | jq -e '.data.already == true' >/dev/null || fail 'setup twice is a no-op'

# what SDKMAN offers
"$binary" sdk available maven --json | jq -e '(.data.available | length == 9) and (.data.available[0].version == "4.0.0-rc-7") and (.data.available[1].version == "3.10.0") and (.data.available[2].version == "3.9.16") and (.data.available[3].version == "3.9.7")' >/dev/null || fail 'available maven'
"$binary" sdk available java --json | jq -e '(.data.available | length == 5) and (.data.available[3].id == "21.0.13.0+9-tem") and (.data.available[1].vendor == "Corretto")' >/dev/null || fail 'available java parses the vendor table'
[[ "$(code "$binary" sdk available ant)" == 2 ]] || fail 'only java, maven and gradle'

# install, default, remove (plan first)
[[ "$(code "$binary" sdk install maven 3.9.7)" == 2 ]] || fail 'install plan exits 2'
[[ ! -d "$tmp/sdkman/candidates/maven/3.9.7" ]] || fail 'plan changed nothing (maven)'
"$binary" sdk install maven 3.9.7 --yes >/dev/null; "$binary" sdk install maven 3.9.6 --yes >/dev/null
grep -q 'sdk install maven 3.9.7' "$LOG" || fail "install ran sdk: $(cat "$LOG")"
"$binary" sdk list maven --json | jq -e '(.data.versions | length == 2) and .data.default == "3.9.7"' >/dev/null || fail 'first install is the default'
"$binary" sdk default maven 3.9.6 --yes >/dev/null
"$binary" sdk list maven --json | jq -e '.data.default == "3.9.6"' >/dev/null || fail 'default moved'
[[ "$(code "$binary" sdk default maven 9.9.9 --yes)" == 4 ]] || fail 'default of an unknown version exits 4'
"$binary" sdk install maven 3.9.6 --yes --json | jq -e '.data.already == true' >/dev/null || fail 'install twice'
"$binary" sdk remove maven 3.9.7 --yes >/dev/null; [[ ! -d "$tmp/sdkman/candidates/maven/3.9.7" ]] || fail 'remove'
[[ "$(code "$binary" sdk install maven 'x;rm -rf' --yes)" == 2 ]] || fail 'a version with shell characters is refused'
"$binary" sdk available maven --json | jq -e '(.data.available | map(select(.installed) | .version)) == ["3.9.6"]' >/dev/null || fail 'available marks the installed version'

# Java goes through SDKMAN when it is there: a major picks the newest Temurin
"$binary" java install 21 --dry-run --json | jq -e '.dry_run' >/dev/null || fail 'java dry run'
"$binary" java install 21 --yes >/dev/null
grep -q 'sdk install java 21.0.13.0+9-tem' "$LOG" || fail "java install picked Temurin 21: $(cat "$LOG")"
"$binary" java list --json | jq -e '.data.homes[] | select(.source == "sdkman") | .removable' >/dev/null || fail 'sdkman homes show in java list'
"$binary" java install 17.0.21.0+10-amzn --yes >/dev/null; grep -q 'sdk install java 17.0.21.0+10-amzn' "$LOG" || fail 'an identifier is passed on'
[[ "$(code "$binary" java install 99 --yes)" == 4 ]] || fail 'a major SDKMAN has no Temurin for exits 4'
"$binary" java remove sdkman-21.0.13.0+9-tem --yes >/dev/null; grep -q 'sdk uninstall java 21.0.13.0+9-tem' "$LOG" || fail 'java remove goes through sdk'
echo "sdk tests passed"

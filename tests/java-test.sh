#!/usr/bin/env bash
# `bxrig java` with fake JDKs and a fake download. Usage: java-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
export HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_STATE_HOME="$tmp/state" BXRIG_JAVA_DIR="$tmp/data/java" BXRIG_JAVA_SYSTEM_DIR="$tmp/jvm" BXRIG_SDKMAN_DIR="$tmp/sdkman"
mkdir -p "$HOME"
code() { set +e; "$@" >/dev/null 2>&1; echo $?; set -e; }
mkjdk() { # dir version vendor
  mkdir -p "$1/bin"; printf '#!/bin/sh\necho java\n' > "$1/bin/java"; chmod +x "$1/bin/java"
  printf 'IMPLEMENTOR="%s"\nJAVA_VERSION="%s"\n' "$3" "$2" > "$1/release"
}
mkjdk "$tmp/jvm/java-17-openjdk" 17.0.13 Arch
mkjdk "$tmp/sdkman/candidates/java/21.0.5-tem" 21.0.5 "Eclipse Adoptium"
mkdir -p "$tmp/sdkman/candidates/java"; ln -s 21.0.5-tem "$tmp/sdkman/candidates/java/current"

"$binary" java list --json | jq -e '(.data.homes | length == 2) and (.data.homes[0].major == 21) and (.data.homes[0].source == "sdkman") and (.data.homes[1].id == "system-java-17-openjdk")' >/dev/null || fail 'list sees sdkman and system homes, newest first, skipping current'
"$binary" java list | grep -q 'sdkman-21.0.5-tem' || fail 'plain list'

# install: a fake download (a tarball with one top folder), plan first
mkdir -p "$tmp/dl/jdk-21.0.13+9"; mkjdk "$tmp/dl/jdk-21.0.13+9" 21.0.13 "Eclipse Adoptium"; echo 'SEMANTIC_VERSION="21.0.13+9"' >> "$tmp/dl/jdk-21.0.13+9/release"; (cd "$tmp/dl" && tar -czf "$tmp/jdk21.tar.gz" jdk-21.0.13+9)
export BXRIG_JAVA_DOWNLOAD_URL="file://$tmp/jdk21.tar.gz" BXRIG_ADOPTIUM_API="file://$tmp/api"
mkdir -p "$tmp/api/v3/info"; echo '{"available_releases":[8,11,17,21],"available_lts_releases":[8,11,17,21],"most_recent_feature_release":21}' > "$tmp/api/v3/info/available_releases"
[[ "$(code "$binary" java install 21)" == 2 ]] || fail 'install plan exits 2'
[[ ! -d "$tmp/data/java" ]] || fail 'plan changed nothing'
"$binary" java install 21 --dry-run --json | jq -e '.dry_run' >/dev/null || fail 'dry run'
[[ "$(code "$binary" java install 99 --yes)" == 4 ]] || fail 'unknown release exits 4'
"$binary" java install 21 --yes --json | jq -e '.data.id == "temurin-21.0.13_9"' >/dev/null || fail 'install'
[[ -x "$tmp/data/java/temurin-21.0.13_9/bin/java" ]] || fail 'unpacked'
"$binary" java install 21 --yes --json | jq -e '.data.already == true' >/dev/null || fail 'install twice is a no-op'
"$binary" java available --json | jq -e '(.data.releases | length == 4) and (.data.releases[3].lts == true)' >/dev/null || fail 'available'

# default: plan, then the env files
[[ "$(code "$binary" java default 21)" == 2 ]] || fail 'default plan exits 2'
"$binary" java default 21 --yes >/dev/null
grep -q 'export JAVA_HOME="'"$tmp"'/data/java/temurin-21.0.13_9"' "$tmp/cfg/bxrig/java.sh" || fail 'java.sh'
grep -q 'set -gx JAVA_HOME' "$tmp/cfg/bxrig/java.fish" || fail 'java.fish'
"$binary" java list --json | jq -e '([.data.homes[] | select(.default)] | length == 1) and (.data.homes[] | select(.default) | .source == "bxrig")' >/dev/null || fail 'default marked'
"$binary" java env 17 | grep -q 'export JAVA_HOME="'"$tmp"'/jvm/java-17-openjdk"' || fail 'env'
[[ "$(code "$binary" java default 99 --yes)" == 4 ]] || fail 'unknown home exits 4'

# remove: only what BxRig installed; the default is cleared with it
[[ "$(code "$binary" java remove system-java-17-openjdk --yes)" == 4 ]] || fail 'system homes are not removed'
[[ "$(code "$binary" java remove temurin-21.0.13_9)" == 2 ]] || fail 'remove plan exits 2'
"$binary" java remove temurin-21.0.13_9 --yes >/dev/null
[[ ! -d "$tmp/data/java/temurin-21.0.13_9" && ! -e "$tmp/cfg/bxrig/java.sh" ]] || fail 'removed with its default'
"$binary" java default --unset --yes >/dev/null
[[ "$(code "$binary" java frobnicate)" == 2 ]] || fail 'bad usage exits 2'
echo "java tests passed"

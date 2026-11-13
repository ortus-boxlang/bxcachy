#!/usr/bin/env bash
# `bxcachy boxlang` with fake bvm, mvm, bx-module, code and curl (a canned ForgeBox answer). Usage: boxlang-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/nobin"; export LOG="$tmp/log"; : > "$LOG"
logger() { printf '#!/usr/bin/env bash\necho "%s $*" >> "$LOG"\n%s\n' "$1" "${2:-}" > "$tmp/bin/$1"; }
logger boxlang 'echo "BoxLang 1.19.0"'
logger bvm 'case "$1" in current) echo 1.19.0 ;; list) echo "1.19.0" ;; esac'
logger mvm 'case "$1" in list) echo "0.14.0" ;; esac'
logger matchbox 'echo "MatchBox 0.14.0"'
logger bx-module 'echo "done"'
logger code 'case "$1" in --list-extensions) echo ortus-solutions.vscode-boxlang ;; esac'
logger xdg-open
printf '#!/usr/bin/env bash\necho "curl $*" >> "$LOG"\necho '"'"'{"data":{"results":[{"slug":"bx-ai","title":"BoxLang AI","summary":"AI integration","latestVersion":{"version":"3.7.0"}},{"slug":"bx-sites","title":"Sites","summary":"Static sites","latestVersion":{"version":"1.0.0"}}]}}'"'"'\n' > "$tmp/bin/curl"
chmod +x "$tmp/bin"/*
run() { env HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

run "$binary" boxlang status --json | jq -e '.data.boxlang == "BoxLang 1.19.0" and .data.bvm == "1.19.0" and .data.mvm and .data.bx_module and .data.vscode_extension' >/dev/null || fail "status: $(run "$binary" boxlang status --json)"
# use: bvm and mvm, installing a missing version first
run "$binary" boxlang use 1.19.0 | grep -q 'bvm now uses 1.19.0' || fail 'use'
grep -q '^bvm use 1.19.0' "$LOG" && ! grep -q '^bvm install 1.19.0' "$LOG" || fail "an installed version is not reinstalled: $(cat "$LOG")"
: > "$LOG"; run "$binary" boxlang use snapshot >/dev/null; grep -q '^bvm install snapshot' "$LOG" && grep -q '^bvm use snapshot' "$LOG" || fail 'a missing version is installed first'
: > "$LOG"; run "$binary" boxlang matchbox use 0.15.0 >/dev/null; grep -q '^mvm install 0.15.0' "$LOG" && grep -q '^mvm use 0.15.0' "$LOG" || fail 'mvm'
[[ "$(code "$binary" boxlang use 'a;b')" == 4 ]] || fail 'a bad version exits 4'
# modules: the live ForgeBox list, then bx-module
run "$binary" boxlang modules list | grep -q 'bx-ai  3.7.0  AI integration' || fail 'forgebox list'
grep -q 'type=boxlang-modules' "$LOG" || fail 'forgebox api url'
: > "$LOG"; run "$binary" boxlang modules search ai >/dev/null; grep -q 'searchTerm=ai' "$LOG" || fail 'search term'
: > "$LOG"; run "$binary" boxlang modules install bx-ai bx-sites >/dev/null; grep -q '^bx-module install bx-ai bx-sites' "$LOG" || fail 'bx-module install'
run "$binary" boxlang modules update >/dev/null; grep -q '^bx-module update --force' "$LOG" || fail 'update'
[[ "$(code "$binary" boxlang modules install)" == 4 ]] || fail 'install needs names'
[[ "$(code "$binary" boxlang modules install 'x;y')" == 4 ]] || fail 'bad module name exits 4'
# vscode
: > "$LOG"; run "$binary" boxlang vscode | grep -q 'ortus-solutions.vscode-boxlang' || fail 'vscode'
grep -q '^code --install-extension ortus-solutions.vscode-boxlang --force' "$LOG" && grep -q 'vscode-boxlang-developer-pack' "$LOG" || fail 'both extensions'
rc=0; env HOME="$tmp/home" PATH="$tmp/nobin" "$binary" boxlang vscode >/dev/null 2>&1 || rc=$?; [[ "$rc" == 4 ]] || fail "no code exits 4 (got $rc)"
# links and the welcome page
run "$binary" boxlang links --json | jq -e '(.data.links | map(.url) | index("https://try.boxlang.io") != null) and (.data.links | length) >= 10' >/dev/null || fail 'links'
run "$binary" boxlang welcome >/dev/null; f="$tmp/cfg/bxcachy/welcome.html"
grep -q 'Try BoxLang' "$f" && grep -q 'matchbox.boxlang.io' "$f" && grep -q 'xdg-open' "$LOG" || fail 'welcome page'
[[ "$(code "$binary" boxlang nope)" == 2 ]] || fail 'usage exits 2'
echo "boxlang-test ok"

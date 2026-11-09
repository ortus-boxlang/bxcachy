#!/usr/bin/env bash
# Catalog commands against the embedded catalog. Usage: catalog-test.sh [binary]
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
bin="$(cd "$(dirname "${1:-./bxcachy}")" && pwd)/$(basename "${1:-./bxcachy}")"
fail() { echo "FAIL: $*" >&2; exit 1; }
code() { set +e; "$@" >/dev/null 2>&1; local rc=$?; set -e; echo "$rc"; }
cat="$root/catalog/apps.json"
# The source of truth and the embedded copy agree.
"$root/bootstrap/gen-catalog.sh" --check >/dev/null || fail 'embedded catalog is stale'
[[ "$("$bin" catalog version --json | jq -r .data.apps)" == "$(jq '.apps|length' "$cat")" ]] || fail 'app count differs'
[[ "$("$bin" catalog list --json | jq '.data|length')" == "$(jq '.apps|length' "$cat")" ]] || fail 'list count'
[[ "$("$bin" catalog list --tier=default --json | jq '.data|length')" == "$(jq '[.apps[]|select(.tier=="default")]|length' "$cat")" ]] || fail 'tier filter'
[[ "$("$bin" catalog list --group=infra --category=Containers --json | jq '.data|length')" == "$(jq '[.apps[]|select(.group=="infra" and .category=="Containers")]|length' "$cat")" ]] || fail 'group+category filter'
[[ "$("$bin" catalog groups --json | jq '.data|length')" == "$(jq '.groups|length' "$cat")" ]] || fail 'groups'
"$bin" catalog show podman | grep -Fq 'Podman' || fail 'show'
[[ "$("$bin" catalog show podman --json | jq -r .data.id)" == podman ]] || fail 'show --json'
[[ "$(code "$bin" catalog show nope)" == 3 ]] || fail 'unknown id exits 3'
[[ "$(code "$bin" catalog show)" == 2 ]] || fail 'show needs an id'
[[ "$(code "$bin" catalog bogus)" == 2 ]] || fail 'unknown verb exits 2'
[[ "$(code "$bin" catalog check)" == 0 ]] || fail 'catalog check must pass'
[[ "$("$bin" catalog check --json | jq '.data.errors|length')" == 0 ]] || fail 'check errors'
# Presentation metadata is complete for every app.
[[ "$(jq '[.apps[]|select((.description//"")=="")]|length' "$cat")" == 0 ]] || fail 'app without description'
[[ "$(jq '[.groups[].id] as $g | [.apps[]|select(.group as $x|$g|index($x)|not)]|length' "$cat")" == 0 ]] || fail 'app in unknown group'
# Profiles and shells (schema 3 additions).
[[ "$(jq '.profiles|length' "$cat")" -ge 12 ]] || fail 'profiles missing'
[[ "$(jq '[.profiles[].id] as $p | [.apps[]|select(.profiles)|.profiles|keys[]|select(. as $k|$p|index($k)|not)]|length' "$cat")" == 0 ]] || fail 'app in unknown profile'
[[ "$(jq '[.apps[]|select(.shells)|.shells[]|select(.!="hyprland" and .!="plasma")]|length' "$cat")" == 0 ]] || fail 'unknown shell'
[[ "$("$bin" catalog show git --json | jq -r '.data.profiles.core')" == default ]] || fail 'git is a default core app'
[[ "$("$bin" catalog show hyprsunset --json | jq -r '.data.shells[0]')" == hyprland ]] || fail 'hyprsunset targets hyprland'
# Negative cases for the check itself (needs a MatchBox to run the script).
mb="${MATCHBOX:-$(command -v matchbox || true)}"
if [[ -n "$mb" ]]; then
 (cd "$root/src" && "$mb" ../tests/catalog_check.bxs) | tail -n 1 | grep -Fq 'negative tests passed' || fail 'catalog check negative tests'
fi
# Owner's 2026-11-09 corrections
for id in amp-desktop elsewhen learn-omarchy; do [[ "$(jq --arg i "$id" '[.apps[]|select(.id==$i)]|length' "$cat")" == 0 ]] || fail "$id must not be in the catalog"; done
for id in datagrip opencode-desktop; do [[ "$(jq -r --arg i "$id" '.apps[]|select(.id==$i)|.tier' "$cat")" == optional ]] || fail "$id is an optional app"; done
[[ "$(jq -r '.apps[]|select(.id=="pi-agent")|"\(.source) \(.tier) \(.targets[0])"' "$cat")" == 'aur optional pi-bin' ]] || fail 'pi-agent is the optional AUR package pi-bin'
[[ "$(jq -r '.apps[]|select(.id=="codex-cli")|"\(.source) \(.tier) \(.targets[0])"' "$cat")" == 'pacman optional openai-codex' ]] || fail 'codex-cli is the optional package openai-codex'
for id in gemini-cli hermes-agent; do [[ "$(jq -r --arg i "$id" '.apps[]|select(.id==$i)|.tier' "$cat")" == optional ]] || fail "$id is an optional app"; done
[[ "$(jq -r '.apps[]|select(.id=="disktree")|.tier' "$cat")" == default ]] || fail 'disktree is default'
[[ "$(jq '[.apps[]|select(.source=="unresolved")]|length' "$cat")" == 0 ]] || fail 'no app is left unresolved'
echo 'catalog tests passed'

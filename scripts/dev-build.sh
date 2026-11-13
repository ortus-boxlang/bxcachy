#!/usr/bin/env bash
# Build bxcachy with the local MatchBox integration branch (branch `bxcachy` in /home/user/matchbox,
# pushed to ortus-boxlang/matchbox) instead of the pinned release, so fixes that are still in review
# can be used now. Output: ./dist/bxcachy
#   MATCHBOX=/path/to/matchbox  override the compiler (default: the local debug build)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
mb="${MATCHBOX:-/home/user/matchbox/target/debug/matchbox}"
[[ -x "$mb" ]] || { echo "MatchBox not found at $mb (build it: cd /home/user/matchbox && cargo build)" >&2; exit 4; }
mkdir -p "$root/dist"
"$root/bootstrap/gen-catalog.sh" >/dev/null
"$root/bootstrap/gen-assets.sh" >/dev/null
"$root/bootstrap/gen-templates.sh" >/dev/null
"$root/bootstrap/gen-themes.sh" >/dev/null
(cd "$root" && "$mb" --target native --output "$root/dist/bxcachy" src/Main.bx)
echo "built $root/dist/bxcachy with $("$mb" --version 2>&1 | head -1)"

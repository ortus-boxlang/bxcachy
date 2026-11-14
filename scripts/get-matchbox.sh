#!/usr/bin/env bash
# Provides the MatchBox that compiles BxRig (box.json toolchain.matchbox): the build of the MatchBox
# `bxcachy` branch that CI publishes to S3, or, when it is not published yet or --from-source is given, a
# release build of that branch made here.
#   get-matchbox.sh DEST_FILE [--from-source]
# Writes DEST_FILE (executable) and DEST_FILE.info (version, ref, commit, source) and prints one summary line.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
dest="${1:-}"; shift || true
from_source=0
for a in "$@"; do case "$a" in --from-source) from_source=1 ;; *) echo "unknown argument: $a" >&2; exit 2 ;; esac; done
[[ -n "$dest" ]] || { echo "usage: get-matchbox.sh DEST_FILE [--from-source]" >&2; exit 2; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 4; }
manifest="${BXRIG_MANIFEST:-$root/box.json}"
want="$(jq -r .toolchain.matchbox.version "$manifest")"
repo="$(jq -r '.toolchain.matchbox.repo // empty' "$manifest")"
ref="$(jq -r '.toolchain.matchbox.ref // empty' "$manifest")"
base="$(jq -r '.toolchain.matchbox.downloads // empty' "$manifest")"
mkdir -p "$(dirname "$dest")"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT

finish() {  # FILE SOURCE COMMIT
  chmod 755 "$1"
  local out; out="$("$1" --version 2>&1 | head -n 1)" || true
  [[ "$out" == *"$want"* ]] || { echo "The MatchBox found reports '${out:-nothing}', box.json wants $want" >&2; return 1; }
  cp "$1" "$dest.new"; mv -f "$dest.new" "$dest"
  # shell-safe: the file is sourced by the workflow (values contain spaces)
  printf 'version=%q\nref=%q\ncommit=%q\nsource=%q\n' "$want" "$ref" "$3" "$2" > "$dest.info"
  echo "MatchBox $want ($2${3:+, $3}) -> $dest"
}

# The evergreen file can be served stale by the CDN, so the build is taken from its immutable folder
# (<version>-<commit>/) named in version-latest.properties; without that file the evergreen folder is used.
build_base() {
  local props v c
  props="$(curl -fsSL -m 30 "$base/version-latest.properties" 2>/dev/null)" || { echo "$base"; return; }
  v="$(sed -n 's/^version=//p' <<<"$props" | head -n1)"; c="$(sed -n 's/^commit=//p' <<<"$props" | head -n1)"
  if [[ -n "$v" && -n "$c" ]]; then echo "$base/$v-$c"; else echo "$base"; fi
}

if (( ! from_source )) && [[ -n "$base" ]]; then
  dl="$(build_base)"
  if curl -fsSL -m 300 -o "$work/matchbox" "$dl/matchbox-linux-x86_64" \
     && curl -fsSL -m 30 -o "$work/matchbox.sha256" "$dl/matchbox-linux-x86_64.sha256"; then
    expected="$(awk '{print $1; exit}' "$work/matchbox.sha256")"
    actual="$(sha256sum "$work/matchbox" | awk '{print $1}')"
    [[ -n "$expected" && "$expected" == "$actual" ]] || { echo "Checksum mismatch for the published MatchBox" >&2; exit 1; }
    finish "$work/matchbox" "published" "" && exit 0
    echo "The published MatchBox does not match box.json; building from source instead" >&2
  else
    echo "No published MatchBox at $base yet; building from source" >&2
  fi
fi

[[ -n "$repo" && -n "$ref" ]] || { echo "box.json has no toolchain.matchbox.repo and ref to build from" >&2; exit 1; }
command -v cargo >/dev/null || { echo "cargo is required to build MatchBox from source" >&2; exit 4; }
git clone --quiet --depth 1 --branch "$ref" "$repo" "$work/src"
commit="$(git -C "$work/src" rev-parse --short HEAD)"
( cd "$work/src" && cargo build --release --locked --features bif-tui 2>&1 | tail -n 5 )
finish "$work/src/target/release/matchbox" "built from $ref" "$commit"

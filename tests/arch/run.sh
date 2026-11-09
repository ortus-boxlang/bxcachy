#!/usr/bin/env bash
# Build the Arch image and run the real-system suite. Usage: tests/arch/run.sh [OUT_DIR]
# Requires a working Docker (or Podman aliased as docker).
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$(realpath -m "${1:-$root/arch-test-out}")"
engine="${CONTAINER_ENGINE:-docker}"
mkdir -p "$out"; chmod a+rwx "$out"
ctx="$root/tests/arch"
if [[ -n "${EXTRA_CA_BUNDLE:-}" ]]; then cp "$EXTRA_CA_BUNDLE" "$ctx/extra-ca.crt"; else rm -f "$ctx/extra-ca.crt"; fi
"$engine" build -t bxcachy-arch-test -f "$root/tests/arch/Dockerfile" "$root/tests/arch"
rc=0
"$engine" run --rm \
  -v "$root":/src:ro -v "$out":/out \
  bxcachy-arch-test bash /src/tests/arch/suite.sh || rc=$?
echo "Logs: $out"
exit "$rc"

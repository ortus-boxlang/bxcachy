#!/usr/bin/env bash
set -euo pipefail
binary="${1:-./bxcachy}"
test -x "$binary"
"$binary" version | grep -F 'BxCachy 0.11.0-dev'
"$binary" doctor | grep -F 'operational'

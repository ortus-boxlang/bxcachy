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
"$binary" install | grep -F 'not yet supported'

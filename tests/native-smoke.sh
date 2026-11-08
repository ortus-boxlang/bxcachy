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

"$binary" optional-plan obs chromium | grep -F 'obs-studio'
"$binary" optional-plan obs chromium | grep -F 'chromium'
"$binary" optional-plan invalid | grep -F 'Unknown optional application'
"$binary" optional-plan | grep -F 'Usage:'
"$binary" help | grep -F 'optional-plan'

"$binary" profile-list | grep -F 'containers: podman'
"$binary" profile-plan jvm | grep -F 'jdk21-openjdk'
"$binary" profile-plan terminal | grep -F 'lazygit'
"$binary" profile-plan invalid | grep -F 'Unknown profile'
"$binary" profile-plan | grep -F 'Usage:'

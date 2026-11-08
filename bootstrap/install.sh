#!/usr/bin/env bash
set -euo pipefail
if ! command -v pacman >/dev/null 2>&1; then
  echo "BxCachy bootstrap requires Arch Linux/CachyOS" >&2
  exit 1
fi
sudo pacman -Syu --needed --noconfirm jdk21-openjdk git curl unzip rustup
echo "Java 21 and Rust toolchain installed."
echo "BVM and MVM require pinned, verified installation instructions before unattended installation."
echo "Install the compiled bxcachy binary from a trusted CI artifact once available."

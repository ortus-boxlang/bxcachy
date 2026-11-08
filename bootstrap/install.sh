#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: install.sh --check | --install --yes" >&2
  exit 2
}
[[ $# -gt 0 ]] || usage
mode="$1"; shift
case "$mode" in
  --check) [[ $# -eq 0 ]] || usage ;;
  --install) [[ $# -eq 1 && "$1" == --yes ]] || usage ;;
  *) usage ;;
esac

command -v pacman >/dev/null 2>&1 || {
  echo "BxCachy requires Arch Linux/CachyOS (pacman)" >&2
  exit 1
}
packages=(jdk21-openjdk git curl unzip rustup)
if [[ "$mode" == --check ]]; then
  for pkg in "${packages[@]}"; do
    if pacman -Qq "$pkg" >/dev/null 2>&1; then
      printf 'installed: %s\n' "$pkg"
    else
      printf 'missing: %s\n' "$pkg"
    fi
  done
  exit 0
fi

sudo pacman -Syu --needed "${packages[@]}"
echo "Java 21 and rustup packages provisioned."
echo "Run 'rustup default stable' as your normal user to activate Rust/Cargo."
echo "BVM, MVM, BoxLang and MatchBox provisioning is still pending verified, version-pinned installers."

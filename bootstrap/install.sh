#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: install.sh --check | --install --yes | --install-toolchains --yes" >&2
  exit 2
}
[[ $# -gt 0 ]] || usage
mode="$1"; shift
case "$mode" in
  --check) [[ $# -eq 0 ]] || usage ;;
  --install|--install-toolchains) [[ $# -eq 1 && "$1" == --yes ]] || usage ;;
  *) usage ;;
esac

command -v pacman >/dev/null 2>&1 || {
  echo "BxCachy requires Arch Linux/CachyOS (pacman)" >&2
  exit 1
}
packages=(jdk21-openjdk git curl unzip rustup)
MATCHBOX_VERSION="0.12.0"
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

if [[ "$mode" == --install-toolchains ]]; then
  command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
  command -v java >/dev/null 2>&1 || { echo "Java 21 is required" >&2; exit 1; }
  java -version 2>&1 | grep -Eq 'version "21[."]|openjdk 21' || { echo "Java 21 is required" >&2; exit 1; }
  [[ "$(id -u)" != 0 ]] || { echo "Toolchains must be installed as a regular user" >&2; exit 1; }
  if ! command -v mvm >/dev/null 2>&1; then
    installer="$(mktemp)"
    trap 'rm -f "$installer"' EXIT
    curl -fsSL https://raw.githubusercontent.com/ortus-boxlang/matchbox-quick-installer/main/install/install.sh -o "$installer"
    bash "$installer"
    rm -f "$installer"
    trap - EXIT
  fi
  export PATH="$HOME/.mvm/bin:$PATH"
  command -v mvm >/dev/null 2>&1 || { echo "MVM installation failed" >&2; exit 1; }
  mvm install "$MATCHBOX_VERSION"
  mvm use "$MATCHBOX_VERSION"
  matchbox --version | grep -F "$MATCHBOX_VERSION"
  echo "MatchBox $MATCHBOX_VERSION installed and verified."
  echo "BVM and BoxLang provisioning remains pending."
  exit 0
fi

sudo pacman -Syu --needed "${packages[@]}"
echo "Java 21 and rustup packages provisioned."
echo "Run 'rustup default stable' as your normal user to activate Rust/Cargo."
echo "BVM, MVM, BoxLang and MatchBox provisioning is still pending verified, version-pinned installers."

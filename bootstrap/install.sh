#!/usr/bin/env bash
set -euo pipefail

# Pinned versions (owner decision 2026-11-09). BoxLang is pinned to an exact release.
MATCHBOX_VERSION="0.12.0"
BOXLANG_VERSION="1.19.0"
JAVA_MAJOR=21
MIN_FREE_GB=5
BVM_URL="https://install-bvm.boxlang.io"
MVM_URL="https://raw.githubusercontent.com/ortus-boxlang/matchbox-quick-installer/main/install/install.sh"

usage() {
  echo "Usage: install.sh --check | --plan | --install --yes | --install-toolchains --yes" >&2
  exit 2
}
[[ $# -gt 0 ]] || usage
mode="$1"; shift
case "$mode" in
  --check|--plan) [[ $# -eq 0 ]] || usage ;;
  --install|--install-toolchains) [[ $# -eq 1 && "$1" == --yes ]] || usage ;;
  *) usage ;;
esac

command -v pacman >/dev/null 2>&1 || {
  echo "BxCachy requires Arch Linux/CachyOS (pacman)" >&2
  exit 1
}
packages=(jdk21-openjdk git curl unzip rustup base-devel)

# ---- Read-only inspection (used by --check and --plan; never changes the system) ----
BIN_DIR="${BXCACHY_BIN_DIR:-$HOME/.local/bin}"
BVM_HOME="${BVM_HOME:-$HOME/.bvm}"
MVM_HOME="${MVM_HOME:-$HOME/.mvm}"
probe_path="$BVM_HOME/bin:$BVM_HOME/current/bin:$MVM_HOME/bin:$HOME/.cargo/bin:$BIN_DIR:$PATH"

tool_path() { PATH="$probe_path" command -v "$1" 2>/dev/null; }
first_version() { grep -m1 -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' || true; }
tool_version() {  # NAME [ARG]: first x.y[.z] printed by the tool, empty if unknown
  local bin; bin="$(tool_path "$1")" || return 0
  PATH="$probe_path" "$bin" "${2:---version}" 2>&1 | first_version || true
}
os_id() { ( . "${BXCACHY_OS_RELEASE:-/etc/os-release}" 2>/dev/null; echo "${ID:-unknown}|${ID_LIKE:-}" ) || echo "unknown|"; }

inspect() {
  missing_pkgs=()
  for pkg in "${packages[@]}"; do pacman -Qq "$pkg" >/dev/null 2>&1 || missing_pkgs+=("$pkg"); done
  IFS='|' read -r os_name os_like <<<"$(os_id)"
  if [[ "$os_name" == cachyos || "$os_name" == arch || " $os_like " == *" arch "* ]]; then os_ok=1; else os_ok=0; fi
  cpu="$(uname -m)"
  if [[ "$(id -u)" == 0 ]]; then is_root=1; else is_root=0; fi
  have_sudo=0; command -v sudo >/dev/null 2>&1 && have_sudo=1
  free_gb="$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2{printf "%d", $4/1048576}')"; free_gb="${free_gb:-0}"
  if [[ "${BXCACHY_SKIP_NETWORK:-0}" == 1 ]]; then net="skipped"
  elif curl -fsSI -m 6 -o /dev/null https://downloads.ortussolutions.com/ >/dev/null 2>&1; then net="ok"; else net="unreachable"; fi
  java_ver=""; if jb="$(tool_path java)"; then java_ver="$(PATH="$probe_path" "$jb" -version 2>&1 | grep -m1 -oE 'version "[0-9][0-9.]*' | grep -oE '[0-9][0-9.]*' || true)"; fi
  java_major="${java_ver%%.*}"
  have_yay=0; tool_path yay >/dev/null && have_yay=1
  mvm_ver="$(tool_version mvm)"; have_mvm=0; tool_path mvm >/dev/null && have_mvm=1
  mb_ver="$(tool_version matchbox)"
  have_bvm=0; tool_path bvm >/dev/null && have_bvm=1; bvm_ver="$(tool_version bvm)"
  bl_ver="$(tool_version boxlang)"
  rust_ver="$(tool_version rustc)"; have_rustup=0; tool_path rustup >/dev/null && have_rustup=1
  have_bxcachy=0; tool_path bxcachy >/dev/null && have_bxcachy=1; bx_ver="$(tool_version bxcachy version)"
  case ":$PATH:" in *":$BIN_DIR:"*) bin_on_path=1 ;; *) bin_on_path=0 ;; esac
}

# Ordered list of steps still needed, derived from inspect(). One line per step.
build_steps() {
  steps=()
  if (( ${#missing_pkgs[@]} )); then
    steps+=("packages|sudo pacman -Syu --needed ${missing_pkgs[*]}|installs missing packages and also upgrades the system")
  fi
  if (( ! have_yay )); then
    steps+=("yay|sudo pacman -S --needed yay|AUR helper, found in the cachyos repository; only runs if yay is absent")
  fi
  if (( ! have_mvm )); then
    steps+=("mvm|download and run $MVM_URL|external script, shown first; typed EXECUTE or --allow-external-scripts")
  fi
  if [[ "$mb_ver" != "$MATCHBOX_VERSION" ]]; then
    steps+=("matchbox|mvm install $MATCHBOX_VERSION && mvm use $MATCHBOX_VERSION|pinned MatchBox compiler")
  fi
  if (( ! have_bvm )); then
    steps+=("bvm|download and run $BVM_URL|external script, shown first; typed EXECUTE or --allow-external-scripts")
  fi
  if [[ "$bl_ver" != "$BOXLANG_VERSION" ]]; then
    steps+=("boxlang|bvm install $BOXLANG_VERSION && bvm use $BOXLANG_VERSION|pinned BoxLang runtime")
  fi
  if (( ! have_rustup )) || [[ -z "$rust_ver" ]]; then
    steps+=("rust|rustup default stable|activates Rust and Cargo for your user")
  fi
  if (( ! have_bxcachy )); then
    steps+=("binary|matchbox --target native src/bxcachy.bxs, then install to $BIN_DIR/bxcachy|built from source, no sudo")
  fi
  if (( have_bxcachy && ! bin_on_path )); then
    steps+=("path|add $BIN_DIR to PATH|bxcachy is installed but its directory is not on PATH")
  fi
}

report_check() {
  echo "== system =="
  printf 'os: %s (%s)\n' "$os_name" "$([[ $os_ok == 1 ]] && echo supported || echo unsupported)"
  printf 'cpu: %s (%s)\n' "$cpu" "$([[ $cpu == x86_64 ]] && echo supported || echo unsupported)"
  printf 'user: %s\n' "$([[ $is_root == 1 ]] && echo 'root (run as a normal user)' || echo normal)"
  printf 'sudo: %s\n' "$([[ $have_sudo == 1 ]] && echo available || echo missing)"
  printf 'disk-free: %s GB (%s)\n' "$free_gb" "$([[ $free_gb -ge $MIN_FREE_GB ]] && echo ok || echo "need $MIN_FREE_GB")"
  printf 'network: %s\n' "$net"
  echo "== packages =="
  for pkg in "${packages[@]}"; do
    if [[ " ${missing_pkgs[*]-} " == *" $pkg "* ]]; then printf 'missing: %s\n' "$pkg"; else printf 'installed: %s\n' "$pkg"; fi
  done
  printf '%s: yay\n' "$([[ $have_yay == 1 ]] && echo installed || echo missing)"
  echo "== tools =="
  printf 'java: %s (want %s)\n' "${java_ver:-missing}" "$JAVA_MAJOR"
  printf 'mvm: %s\n' "$([[ $have_mvm == 1 ]] && echo "${mvm_ver:-installed}" || echo missing)"
  printf 'matchbox: %s (want %s)\n' "${mb_ver:-missing}" "$MATCHBOX_VERSION"
  printf 'bvm: %s\n' "$([[ $have_bvm == 1 ]] && echo "${bvm_ver:-installed}" || echo missing)"
  printf 'boxlang: %s (want %s)\n' "${bl_ver:-missing}" "$BOXLANG_VERSION"
  printf 'rust: %s\n' "${rust_ver:-no default toolchain}"
  printf 'bxcachy: %s\n' "$([[ $have_bxcachy == 1 ]] && echo "${bx_ver:-installed}" || echo missing)"
  echo "== path =="
  printf 'bin-dir: %s (%s)\n' "$BIN_DIR" "$([[ $bin_on_path == 1 ]] && echo on-PATH || echo not-on-PATH)"
  if (( ${#steps[@]} )); then printf 'summary: %d step(s) needed, run install.sh --plan\n' "${#steps[@]}"; else echo "summary: ready"; fi
}

report_plan() {
  echo "Read-only plan. Nothing below has been run."
  if (( ${#steps[@]} == 0 )); then echo "Nothing to do: everything is installed at the pinned versions."; return; fi
  local i=0 line name cmd why
  for line in "${steps[@]}"; do
    i=$((i+1)); IFS='|' read -r name cmd why <<<"$line"
    printf '%d. %s\n   run: %s\n   why: %s\n' "$i" "$name" "$cmd" "$why"
  done
  echo "To apply the package steps: install.sh --install --yes. Toolchain steps: install.sh --install-toolchains --yes."
}

if [[ "$mode" == --check || "$mode" == --plan ]]; then
  inspect; build_steps
  if [[ "$mode" == --check ]]; then report_check; else report_plan; fi
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

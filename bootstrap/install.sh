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
  echo "Usage: install.sh --check | --plan | --install --yes | --install-toolchains --yes [--allow-external-scripts]" >&2
  exit 2
}
[[ $# -gt 0 ]] || usage
mode="$1"; shift
case "$mode" in
  --check|--plan) [[ $# -eq 0 ]] || usage ;;
  --install) [[ $# -eq 1 && "$1" == --yes ]] || usage ;;
  --install-toolchains)
    yes=0; allow_external=0
    for arg in "$@"; do
      case "$arg" in --yes) yes=1 ;; --allow-external-scripts) allow_external=1 ;; *) usage ;; esac
    done
    [[ $yes -eq 1 ]] || usage ;;
  *) usage ;;
esac
allow_external="${allow_external:-0}"

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
is_interactive() { [[ "${BXCACHY_INTERACTIVE:-0}" == 1 || ( -t 0 && -t 1 ) ]]; }
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
    steps+=("yay|sudo pacman -S --needed yay|AUR helper, found in the cachyos repository; only runs if yay is absent (part of --install)")
  fi
  if (( ! have_mvm )); then
    steps+=("mvm|download and run $MVM_URL|external script, shown first; typed EXECUTE or --allow-external-scripts")
  fi
  if [[ "$mb_ver" != "$MATCHBOX_VERSION" ]]; then
    steps+=("matchbox|mvm install $MATCHBOX_VERSION && mvm use $MATCHBOX_VERSION|pinned MatchBox compiler")
  fi
  if (( ! have_bvm )); then
    steps+=("bvm|download and run $BVM_URL|external script, shown first; typed EXECUTE or --allow-external-scripts; it may add BVM to your shell startup files")
  fi
  if [[ "$bl_ver" != "$BOXLANG_VERSION" ]]; then
    steps+=("boxlang|bvm install $BOXLANG_VERSION && bvm use $BOXLANG_VERSION|pinned BoxLang runtime")
  fi
  if (( ! have_rustup )) || [[ -z "$rust_ver" ]]; then
    steps+=("rust|rustup default stable|activates Rust and Cargo for your user (part of --install)")
  fi
  if (( ! have_bxcachy )); then
    steps+=("binary|matchbox --target native src/bxcachy.bxs, then install to $BIN_DIR/bxcachy|built from source, no sudo")
  fi
  if (( have_bxcachy && ! bin_on_path )); then
    steps+=("path|add $BIN_DIR to PATH yourself|BxCachy does not edit shell startup files; the commands are printed by --install")
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
  # Re-runnable: only the steps still needed are performed. Runs as the normal user.
  command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
  [[ "$(id -u)" != 0 ]] || { echo "Toolchains must be installed as a regular user" >&2; exit 1; }
  inspect
  [[ "$java_major" == "$JAVA_MAJOR" ]] || { echo "Java $JAVA_MAJOR is required (found: ${java_ver:-none})" >&2; exit 1; }
  export PATH="$probe_path"
  cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/bxcachy/external"

  # Download an external installer, show what it is, and run it only after approval:
  # typed EXECUTE when interactive, or --allow-external-scripts when unattended.
  run_external() {  # NAME URL
    local name="$1" url="$2" file hash lines answer
    mkdir -p "$cache_dir"; chmod 700 "$cache_dir"
    file="$(mktemp "$cache_dir/$name.XXXXXX.sh")"
    if ! curl -fsSL --retry 3 --retry-delay 2 "$url" -o "$file"; then echo "Download failed: $url" >&2; rm -f "$file"; exit 1; fi
    [[ -s "$file" ]] || { echo "Empty download: $url" >&2; rm -f "$file"; exit 1; }
    chmod 600 "$file"
    hash="$(sha256sum "$file" | cut -d' ' -f1)"; lines="$(wc -l < "$file")"
    printf 'External script: %s\n  url:    %s\n  saved:  %s (%s lines)\n  sha256: %s\n  first lines:\n' "$name" "$url" "$file" "$lines" "$hash"
    head -n 15 "$file" | sed 's/^/    | /'
    if (( allow_external )); then
      echo "  approved by --allow-external-scripts"
    elif is_interactive; then
      printf 'Type EXECUTE to run this script as %s (read it first: %s), anything else cancels: ' "$(id -un)" "$file"
      read -r answer || answer=""
      [[ "$answer" == EXECUTE ]] || { echo "Cancelled. Nothing was run." >&2; exit 2; }
    else
      echo "Not running $name unattended. Re-run with --allow-external-scripts to approve external scripts." >&2
      exit 2
    fi
    if ! bash "$file"; then echo "$name installer failed (script kept at $file)" >&2; exit 1; fi
  }

  done_any=0
  if (( ! have_mvm )); then
    run_external mvm "$MVM_URL"; done_any=1
    tool_path mvm >/dev/null || { echo "MVM installation failed: mvm not found afterwards" >&2; exit 1; }
  fi
  if [[ "$(tool_version matchbox)" != "$MATCHBOX_VERSION" ]]; then
    mvm install "$MATCHBOX_VERSION"; mvm use "$MATCHBOX_VERSION"; done_any=1
    [[ "$(tool_version matchbox)" == "$MATCHBOX_VERSION" ]] || { echo "MatchBox $MATCHBOX_VERSION not active after install" >&2; exit 1; }
    echo "MatchBox $MATCHBOX_VERSION installed and verified."
  fi
  if (( ! have_bvm )); then
    run_external bvm "$BVM_URL"; done_any=1
    tool_path bvm >/dev/null || { echo "BVM installation failed: bvm not found afterwards" >&2; exit 1; }
    echo "Note: the BVM installer may add BVM to your shell startup files; open a new shell to pick that up."
  fi
  if [[ "$(tool_version boxlang)" != "$BOXLANG_VERSION" ]]; then
    bvm install "$BOXLANG_VERSION"; bvm use "$BOXLANG_VERSION"; done_any=1
    [[ "$(tool_version boxlang)" == "$BOXLANG_VERSION" ]] || { echo "BoxLang $BOXLANG_VERSION not active after install (found: $(tool_version boxlang))" >&2; exit 1; }
    echo "BoxLang $BOXLANG_VERSION installed and verified."
  fi
  if (( ! done_any )); then echo "Nothing to do: MVM, MatchBox $MATCHBOX_VERSION, BVM and BoxLang $BOXLANG_VERSION are already installed."; fi
  echo "Rust and the bxcachy binary are handled by later steps."
  exit 0
fi

# ---- --install --yes: packages, yay (only if absent), Rust. Runs as the normal user; sudo only for pacman. ----
[[ "$(id -u)" != 0 ]] || { echo "Run as a regular user; sudo is used only for pacman steps" >&2; exit 1; }
inspect
changed=0
# At a terminal pacman shows its own transaction prompt (a full upgrade deserves a second look);
# unattended there is nobody to answer it, and --yes already approved the plan.
pm_flags=(); is_interactive || pm_flags=(--noconfirm)
if (( ${#missing_pkgs[@]} )); then
  echo "Installing missing packages (this also upgrades the system): ${missing_pkgs[*]}"
  sudo pacman -Syu "${pm_flags[@]}" --needed "${missing_pkgs[@]}" || { echo "pacman failed; nothing else was changed" >&2; exit 1; }
  changed=1
else
  echo "packages: all installed"
fi
if ! tool_path yay >/dev/null; then
  echo "Installing yay (AUR helper) from your configured repositories"
  if ! sudo pacman -S "${pm_flags[@]}" --needed yay; then
    echo "yay is not available in your configured repositories. On CachyOS it is in the cachyos repo; otherwise install it from the AUR by hand." >&2
    exit 1
  fi
  changed=1
else
  echo "yay: already installed"
fi
if tool_path rustup >/dev/null && [[ -z "$(tool_version rustc)" ]]; then
  echo "Activating the stable Rust toolchain for your user"
  rustup default stable || { echo "rustup could not install the stable toolchain" >&2; exit 1; }
  [[ -n "$(tool_version rustc)" ]] || { echo "Rust is still not available after rustup default stable" >&2; exit 1; }
  changed=1
else
  echo "rust: ${rust_ver:-rustup not available}"
fi
if (( ! changed )); then echo "Nothing to do for packages, yay and Rust."; fi
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "Note: $BIN_DIR is not on your PATH. BxCachy does not edit shell startup files. Add it yourself:"
     echo "  bash/zsh: export PATH=\"$BIN_DIR:\$PATH\""
     echo "  fish:     fish_add_path $BIN_DIR" ;;
esac
echo "Next: install.sh --install-toolchains --yes"

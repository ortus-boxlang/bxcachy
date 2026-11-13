#!/usr/bin/env bash
# BxCachy installer (published as install.sh): one line, then the setup wizard.
#   curl -fsSL https://downloads.ortussolutions.com/ortussolutions/bxcachy/install.sh | bash
# No human input:
#   curl -fsSL .../install.sh | bash -s -- --yes [--answers answers.json] [--channel beta]
# Options: --yes|-y (never ask), --answers FILE (the wizard answers to apply), --channel stable|beta, --no-wizard, --dry-run,
#          --base-url URL (default https://downloads.ortussolutions.com/ortussolutions/bxcachy; BXCACHY_BASE_URL), -h|--help.
# It downloads the channel's bxcachy binary and bootstrap bundle, verifies the Ed25519 signature of the release information and the SHA-256 of both files, runs the install stages (packages, toolchains,
# binary, core apps) and then the wizard. Everything is logged to ~/.cache/bxcachy/install.log. Needs CachyOS or Arch, a normal user, sudo.
set -Eeuo pipefail

BASE="${BXCACHY_BASE_URL:-https://downloads.ortussolutions.com/ortussolutions/bxcachy}"
CHANNEL="${BXCACHY_CHANNEL:-stable}"
YES=no; ANSWERS=""; WIZARD=yes; DRY=no
# The release public key (Ed25519, base64 of the PEM). CI fills it in when it publishes install.sh; left as is, a development copy only
# checks SHA-256. BXCACHY_PUBKEY_B64 overrides it (tests).
PUBKEY_B64="${BXCACHY_PUBKEY_B64:-@@PUBKEY_B64@@}"
C_RESET="" C_BOLD="" C_DIM="" C_OK="" C_WARN="" C_ERR="" C_ACC=""
RICH=no; INSTALL_LOG=""; TMP=""; PID=""

usage() { sed -n '2,10p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//' || true; }

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes|-y) YES=yes ;;
      --answers) [[ $# -ge 2 ]] || die "--answers needs a file"; ANSWERS="$2"; shift ;;
      --answers=*) ANSWERS="${1#*=}" ;;
      --channel) [[ $# -ge 2 ]] || die "--channel needs stable or beta"; CHANNEL="$2"; shift ;;
      --channel=*) CHANNEL="${1#*=}" ;;
      --base-url) [[ $# -ge 2 ]] || die "--base-url needs a URL"; BASE="$2"; shift ;;
      --base-url=*) BASE="${1#*=}" ;;
      --no-wizard) WIZARD=no ;;
      --dry-run) DRY=yes ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown option: $1 (try --help)" ;;
    esac
    shift
  done
  [[ "$CHANNEL" == stable || "$CHANNEL" == beta ]] || die "the channel must be stable or beta"
  [[ -z "$ANSWERS" || -f "$ANSWERS" ]] || die "answers file not found: $ANSWERS"
}

setup_terminal() {
  if [[ -t 1 && ${TERM:-dumb} != dumb && -z ${NO_COLOR:-} ]]; then
    C_RESET=$'\033[0m' C_BOLD=$'\033[1m' C_DIM=$'\033[2m' C_OK=$'\033[38;2;0;255;120m' C_WARN=$'\033[33m' C_ERR=$'\033[31m' C_ACC=$'\033[38;2;0;219;255m'
    RICH=yes
  fi
}

info() { printf '  %s✓%s  %s\n' "$C_OK" "$C_RESET" "$*"; }
note() { printf '  %s·%s  %s\n' "$C_DIM" "$C_RESET" "$*"; }
warn() { printf '  %s!%s  %s\n' "$C_WARN" "$C_RESET" "$*" >&2; }
die()  { printf '  %s×%s  %s\n' "$C_ERR" "$C_RESET" "$*" >&2; [[ -z "$INSTALL_LOG" ]] || printf '  %sLog: %s%s\n' "$C_DIM" "$INSTALL_LOG" "$C_RESET" >&2; exit 1; }
section() { printf '\n  %s%s%s%s\n\n' "$C_ACC" "$C_BOLD" "$*" "$C_RESET"; }

cleanup() {
  [[ -z "$PID" ]] || kill "$PID" 2>/dev/null || true
  [[ -z "$TMP" ]] || rm -rf "$TMP"
  [[ "$RICH" != yes ]] || printf '\033[?25h'
}
trap cleanup EXIT
trap 'printf "\n"; die "cancelled"' INT TERM

# The wordmark in the Ortus gradient (cyan #00DBFF to green #00FF78), one colour per row.
banner() {
  local -a rows=(
    '███████▄               ▄█████▄                        ███'
    '███   ███  ▄▄▄   ▄▄▄  ▄██   ███   ▄▄▄▄▄      ▄▄▄▄▄    ███ ▄▄▄    ▄▄     ▄▄'
    '███▄▄▄█▀    ██▄ ██▀   ███        ██▀▀▀██    ██▀▀▀██▄  ███▀▀▀██   ▀██   ██▀'
    '███▀▀▀██▄    ▀███▀    ███         ▄▄▄▄██   ███    ▀   ███   ██▄   ██▄ ███'
    '███   ███    ▄███▄    ███   ▄▄▄ ███▀▀▀██   ███    ▄   ███   ███    ██▄██'
    '███▄▄▄██▀   ██▀ ▀██    ██▄▄▄██▀ ███▄▄▄██    ██▄▄▄██▀  ███   ███     ███'
    '▀▀▀▀▀▀▀    ▀▀▀   ▀▀▀    ▀▀▀▀▀    ▀▀▀▀ ▀▀     ▀▀▀▀▀    ▀▀▀   ▀▀▀     ██▀'
    '                                                                   ███'
  )
  local i n=${#rows[@]} r g b
  printf '\n'
  for ((i = 0; i < n; i++)); do
    if [[ $RICH == yes ]]; then
      r=0; g=$((219 + (255 - 219) * i / (n - 1))); b=$((255 + (120 - 255) * i / (n - 1)))
      printf '  \033[38;2;%d;%d;%dm%s%s\n' "$r" "$g" "$b" "${rows[i]}" "$C_RESET"
    else
      printf '  %s\n' "${rows[i]}"
    fi
  done
  printf '\n  %sYour developer machine, set up in minutes.%s\n' "$C_BOLD" "$C_RESET"
  printf '  %sPowered by BoxLang · www.boxlang.io%s\n' "$C_DIM" "$C_RESET"
}

# run_task LABEL CMD...: a spinner while CMD runs, its output in the log; failures print the tail of the log.
run_task() {
  local label=$1 result frame=0
  local -a frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  shift
  printf '\n--- %s ---\n' "$label" >>"$INSTALL_LOG"
  if [[ $RICH == yes ]]; then
    "$@" >>"$INSTALL_LOG" 2>&1 &
    PID=$!
    printf '\033[?25l'
    while kill -0 "$PID" 2>/dev/null; do
      printf '\r  %s%s%s  %s\033[K' "$C_ACC" "${frames[frame % 10]}" "$C_RESET" "$label"
      frame=$((frame + 1)); sleep 0.1
    done
    if wait "$PID"; then result=0; else result=$?; fi
    PID=""
    printf '\r\033[K\033[?25h'
  else
    printf '  …  %s\n' "$label"
    if "$@" >>"$INSTALL_LOG" 2>&1; then result=0; else result=$?; fi
  fi
  if ((result != 0)); then
    tail -n 15 "$INSTALL_LOG" >&2
    die "$label failed"
  fi
  info "$label"
}

# A task that needs the terminal (sudo password, the wizard): no spinner, output live and logged.
run_live() {
  local label=$1
  shift
  printf '\n--- %s ---\n' "$label" >>"$INSTALL_LOG"
  "$@" || die "$label failed"
}

fetch() { curl -fsSL --retry 3 --retry-delay 2 --max-time 600 -o "$2" "$1"; }

verify_sha() {   # verify_sha FILE SHAFILE
  local want got
  want="$(awk '{print $1}' "$2")"; got="$(sha256sum "$1" | awk '{print $1}')"
  [[ -n "$want" && "$want" == "$got" ]]
}

# verify_properties FILE SIGFILE: the release information is signed (Ed25519); with a key a missing or bad signature is fatal.
verify_properties() {
  [[ "$PUBKEY_B64" != "@@PUBKEY_B64@@" && -n "$PUBKEY_B64" ]] || { note "unsigned development copy: checking SHA-256 only"; return 0; }
  command -v openssl >/dev/null 2>&1 || die "openssl is required to verify the release signature"
  printf '%s' "$PUBKEY_B64" | base64 -d > "$TMP/release.pub" 2>/dev/null || die "the embedded release key is malformed"
  [[ -s "$TMP/release.pub" ]] || die "the embedded release key is empty"
  openssl pkeyutl -verify -pubin -inkey "$TMP/release.pub" -rawin -in "$1" -sigfile "$2" >/dev/null 2>&1 \
    || die "the release signature is invalid; nothing was installed"
  info "release signature verified (Ed25519)"
}

prop() { sed -n "s/^$2=//p" "$1" | head -n 1; }

preflight() {
  # BXCACHY_INSTALL_ALLOW_ROOT=1 is for the test suite only
  [[ "$(id -u)" != 0 || "${BXCACHY_INSTALL_ALLOW_ROOT:-}" == 1 ]] || die "run this as your normal user, not as root (sudo is used only where needed)"
  command -v pacman >/dev/null 2>&1 || die "BxCachy needs CachyOS or Arch Linux (pacman was not found)"
  command -v curl >/dev/null 2>&1 || die "curl is required"
  command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required"
  [[ "$(uname -m)" == x86_64 ]] || die "only x86_64 is supported for now (found $(uname -m))"
  command -v sudo >/dev/null 2>&1 || die "sudo is required"
  info "CachyOS or Arch, normal user, x86_64"
}

ask_sudo() {
  if [[ $YES == yes ]]; then
    sudo -n true 2>/dev/null || die "--yes needs passwordless sudo (or run sudo -v first): sudo asked for a password"
  else
    printf '  %sAdministrator access is needed for pacman.%s\n' "$C_DIM" "$C_RESET"
    sudo -v </dev/tty || die "sudo was not granted"
  fi
}

confirm() {
  [[ $YES == yes ]] && return 0
  [[ -r /dev/tty ]] || { note "no terminal to ask on; continuing (use --yes to silence this)"; return 0; }
  printf '\n  Install BxCachy (%s channel) and start the setup wizard? [Y/n] ' "$CHANNEL" >/dev/tty
  local a; IFS= read -r a </dev/tty || a=n
  case "${a:-Y}" in [Yy]*|"") ;; *) printf '  Cancelled. Nothing was changed.\n'; exit 2 ;; esac
}

main() {
  parse_args "$@"
  setup_terminal
  mkdir -p "$HOME/.cache/bxcachy"
  INSTALL_LOG="$HOME/.cache/bxcachy/install.log"; : >"$INSTALL_LOG"
  banner
  section "Checking this machine"
  preflight
  note "channel: $CHANNEL · from $BASE"
  if [[ $DRY == yes ]]; then
    note "dry run: would download, verify and install, then run the wizard$( [[ -n "$ANSWERS" ]] && echo " with $ANSWERS" )"
    exit 0
  fi
  confirm
  TMP="$(mktemp -d)"
  section "Downloading"
  run_task "the $CHANNEL release information" fetch "$BASE/$CHANNEL/version-latest.properties" "$TMP/version.properties"
  if [[ "$PUBKEY_B64" != "@@PUBKEY_B64@@" && -n "$PUBKEY_B64" ]]; then
    run_task "its signature" fetch "$BASE/$CHANNEL/version-latest.properties.sig" "$TMP/version.properties.sig"
  fi
  verify_properties "$TMP/version.properties" "$TMP/version.properties.sig"
  run_task "the bxcachy program" fetch "$BASE/$CHANNEL/bxcachy-linux-x86_64" "$TMP/bxcachy"
  run_task "its checksum" fetch "$BASE/$CHANNEL/bxcachy-linux-x86_64.sha256" "$TMP/bxcachy.sha256"
  verify_sha "$TMP/bxcachy" "$TMP/bxcachy.sha256" || die "the bxcachy download does not match its SHA-256; nothing was installed"
  if [[ "$PUBKEY_B64" != "@@PUBKEY_B64@@" && -n "$PUBKEY_B64" ]]; then
    [[ "$(prop "$TMP/version.properties" sha256)" == "$(sha256sum "$TMP/bxcachy" | awk '{print $1}')" ]] || die "bxcachy does not match the signed release information; nothing was installed"
  fi
  info "bxcachy verified (SHA-256$( [[ "$PUBKEY_B64" != "@@PUBKEY_B64@@" && -n "$PUBKEY_B64" ]] && echo ' and signature'))"
  run_task "the install bundle" fetch "$BASE/$CHANNEL/bootstrap.tar.gz" "$TMP/bootstrap.tar.gz"
  run_task "its checksum" fetch "$BASE/$CHANNEL/bootstrap.tar.gz.sha256" "$TMP/bootstrap.sha256"
  verify_sha "$TMP/bootstrap.tar.gz" "$TMP/bootstrap.sha256" || die "the install bundle does not match its SHA-256; nothing was installed"
  if [[ "$PUBKEY_B64" != "@@PUBKEY_B64@@" && -n "$PUBKEY_B64" ]]; then
    [[ "$(prop "$TMP/version.properties" bootstrap_sha256)" == "$(sha256sum "$TMP/bootstrap.tar.gz" | awk '{print $1}')" ]] || die "the install bundle does not match the signed release information; nothing was installed"
  fi
  info "install bundle verified (SHA-256$( [[ "$PUBKEY_B64" != "@@PUBKEY_B64@@" && -n "$PUBKEY_B64" ]] && echo ' and signature'))"
  mkdir -p "$TMP/src" && tar -xzf "$TMP/bootstrap.tar.gz" -C "$TMP/src"
  [[ -x "$TMP/src/bootstrap/install.sh" || -f "$TMP/src/bootstrap/install.sh" ]] || die "the install bundle has no bootstrap/install.sh"
  chmod +x "$TMP/bxcachy"
  local inst="$TMP/src/bootstrap/install.sh"
  section "Installing"
  ask_sudo
  run_live "packages (pacman)" bash "$inst" packages --yes
  run_task "toolchains (Java, bvm, mvm, BoxLang, MatchBox, Rust)" bash "$inst" toolchains --yes
  run_task "the bxcachy program" bash "$inst" binary --yes --binary "$TMP/bxcachy" --force
  run_live "the core apps" bash "$inst" core --yes
  local bx="${BXCACHY_BIN_DIR:-$HOME/.local/bin}/bxcachy"
  [[ -x "$bx" ]] || die "bxcachy was not installed at $bx"
  if [[ $WIZARD == yes ]]; then
    section "Setup wizard"
    if [[ -n "$ANSWERS" ]]; then run_live "your answers" "$bx" init --answers "$ANSWERS" --yes
    elif [[ $YES == yes || ! -r /dev/tty ]]; then run_live "the default answers" "$bx" init --defaults --yes
    else "$bx" init </dev/tty || warn "the wizard did not finish; run: bxcachy init"
    fi
  fi
  section "Ready"
  info "BxCachy is installed: $bx"
  note "Open a new terminal, then try: bxcachy status, bxcachy menu, bxcachy update check"
  note "Log: $INSTALL_LOG"
}

main "$@"

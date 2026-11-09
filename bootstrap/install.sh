#!/usr/bin/env bash
set -euo pipefail

# Tool versions, installer URLs and the Java package live in box.json at the repository root (loaded below).
# BoxLang follows the latest stable release (owner decision 2026-11-09); BXCACHY_BOXLANG_VERSION=x.y.z pins it.
# MatchBox stays pinned in box.json: it compiles bxcachy itself, so the tested version matters.
# BXCACHY_MVM_VERSION=x.y.z asks the MVM installer for a specific release.
MIN_FREE_GB=5
BOXLANG_LATEST_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang/version-latest.properties"

usage() {
  echo "Usage: install.sh --check | --plan | --install --yes | --install-toolchains --yes [--allow-external-scripts] | --install-binary --yes [--binary PATH] [--force]" >&2
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
  --install-binary)
    yes=0; force=0; binary_arg=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --yes) yes=1; shift ;;
        --force) force=1; shift ;;
        --binary) [[ $# -ge 2 ]] || usage; binary_arg="$2"; shift 2 ;;
        *) usage ;;
      esac
    done
    [[ $yes -eq 1 ]] || usage ;;
  *) usage ;;
esac
allow_external="${allow_external:-0}"

command -v pacman >/dev/null 2>&1 || {
  echo "BxCachy requires Arch Linux/CachyOS (pacman)" >&2
  exit 1
}
packages=(git curl unzip rustup base-devel jq)   # the Java package is added from box.json
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd || true)"

# ---- box.json: the single place that names tool versions (needs jq, so --install installs jq first) ----
MANIFEST="${BXCACHY_MANIFEST:-$root/box.json}"
manifest_error=""
load_manifest() {
  manifest_error=""
  command -v jq >/dev/null 2>&1 || { manifest_error="jq is required to read box.json"; return 1; }
  [[ -f "$MANIFEST" ]] || { manifest_error="box.json not found at $MANIFEST (run this script from a BxCachy checkout)"; return 1; }
  jq -e . "$MANIFEST" >/dev/null 2>&1 || { manifest_error="box.json is not valid JSON: $MANIFEST"; return 1; }
  local key
  for key in .toolchain.java.version .toolchain.java.package .toolchain.boxlang.version .toolchain.bvm.installer \
             .toolchain.mvm.installer .toolchain.matchbox.version .toolchain.rust.channel; do
    jq -e "$key" "$MANIFEST" >/dev/null 2>&1 || { manifest_error="box.json is missing ${key#.}"; return 1; }
  done
  JAVA_MAJOR="$(jq -r .toolchain.java.version "$MANIFEST")"
  JAVA_PKG="$(jq -r .toolchain.java.package "$MANIFEST")"
  MATCHBOX_VERSION="$(jq -r .toolchain.matchbox.version "$MANIFEST")"
  BVM_URL="$(jq -r .toolchain.bvm.installer "$MANIFEST")"
  MVM_URL="$(jq -r .toolchain.mvm.installer "$MANIFEST")"
  RUST_CHANNEL="$(jq -r .toolchain.rust.channel "$MANIFEST")"
  BOXLANG_VERSION="${BXCACHY_BOXLANG_VERSION:-$(jq -r .toolchain.boxlang.version "$MANIFEST")}"
  packages=("$JAVA_PKG" git curl unzip rustup base-devel jq)
}
if load_manifest; then manifest_ok=1; else manifest_ok=0; fi
need_manifest() {  # for modes that cannot work without it
  (( manifest_ok )) && return 0
  echo "$manifest_error" >&2
  [[ "$manifest_error" == jq* ]] && echo "Run install.sh --install --yes first: it installs jq, then reads box.json." >&2
  exit 1
}

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
# Refuse early, with a reason, when the machine cannot be provisioned. Needs inspect() to have run.
preflight_common() {
  [[ "$os_ok" == 1 ]] || { echo "Unsupported OS: $os_name (BxCachy supports CachyOS and Arch Linux)" >&2; exit 1; }
  [[ "$cpu" == x86_64 ]] || { echo "Unsupported CPU: $cpu (x86_64 only)" >&2; exit 1; }
  (( free_gb >= MIN_FREE_GB )) || { echo "Not enough free disk space: ${free_gb} GB free in $HOME, need at least $MIN_FREE_GB GB" >&2; exit 1; }
}
step_run() { local what="$1"; shift; "$@" || { echo "Failed: $what" >&2; exit 1; }; }
# Like step_run, but tries up to three times (0s, 10s, 30s apart): GitHub answers 403 to anonymous API calls
# when a shared address is rate limited, and that is usually brief.
step_retry() {
  local what="$1" wait; shift
  for wait in ${BXCACHY_RETRY_WAITS:-0 10 30}; do
    (( wait )) && { echo "Retrying in ${wait}s: $what" >&2; sleep "$wait"; }
    "$@" && return 0
  done
  echo "Failed after 3 attempts: $what (if GitHub reports HTTP 403, wait a while and rerun; this is a rate limit)" >&2; exit 1
}
# BoxLang's active version, read from BVM's `current` symlink. Running `boxlang --version` starts the whole
# runtime, which rewrites its logs under ~/.boxlang on every call, so routine probes avoid it. Falls back to
# running boxlang only when BVM is not managing it. Install steps still run the real binary to verify.
bl_version() {
  local t
  if [[ -L "$BVM_HOME/current" ]] && t="$(basename "$(readlink "$BVM_HOME/current")")" && [[ "$t" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf '%s\n' "$t"
  else
    tool_version boxlang
  fi
}
# What "want" means for BoxLang: the pinned version, or the newest stable (empty when it cannot be looked up).
boxlang_want() {
  if [[ "$BOXLANG_VERSION" != latest ]]; then printf '%s\n' "$BOXLANG_VERSION"; return 0; fi
  command -v curl >/dev/null 2>&1 || return 0
  curl -fsS -m 8 "$BOXLANG_LATEST_URL" 2>/dev/null | sed -n 's/^version=\([0-9][0-9.]*\).*/\1/p' | head -n 1 || true
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
  bl_ver="$(bl_version)"; bl_want="$(boxlang_want)"
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
  if [[ -z "$bl_ver" ]]; then
    steps+=("boxlang|bvm install $BOXLANG_VERSION && bvm use $BOXLANG_VERSION|BoxLang runtime ($([[ $BOXLANG_VERSION == latest ]] && echo "latest stable${bl_want:+, $bl_want}" || echo "pinned"))")
  elif [[ -n "$bl_want" && "$bl_ver" != "$bl_want" ]]; then
    steps+=("boxlang|bvm install $BOXLANG_VERSION && bvm use $BOXLANG_VERSION|update BoxLang $bl_ver to $bl_want")
  fi
  if (( ! have_rustup )) || [[ -z "$rust_ver" ]]; then
    steps+=("rust|rustup default $RUST_CHANNEL|activates Rust and Cargo for your user (part of --install)")
  fi
  if (( ! have_bxcachy )); then
    steps+=("binary|install.sh --install-binary --yes|builds src/bxcachy.bxs with MatchBox (or use --binary PATH), verifies it, installs to $BIN_DIR/bxcachy, no sudo")
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
  if [[ "$BOXLANG_VERSION" != latest ]]; then bl_desc="$BOXLANG_VERSION (pinned)"
  elif [[ -n "$bl_want" ]]; then bl_desc="latest = $bl_want"
  else bl_desc="latest, version lookup unavailable"; fi
  printf 'boxlang: %s (want %s)\n' "${bl_ver:-missing}" "$bl_desc"
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

if [[ "$mode" == --check || "$mode" == --plan ]] && (( ! manifest_ok )); then
  if [[ "$manifest_error" == jq* ]]; then
    if [[ "$mode" == --check ]]; then
      printf '== manifest ==\nbox.json: cannot be read (%s)\nsummary: 1 step(s) needed, run install.sh --plan\n' "$manifest_error"
    else
      printf 'Read-only plan. Nothing below has been run.\n1. jq\n   run: sudo pacman -S --needed jq\n   why: %s; the other steps depend on versions listed in box.json\nThen run install.sh --plan again for the full list. (install.sh --install --yes installs jq first.)\n' "$manifest_error"
    fi
    exit 0
  fi
  echo "$manifest_error" >&2; exit 1
fi
if [[ "$mode" == --check || "$mode" == --plan ]]; then
  inspect; build_steps
  if [[ "$mode" == --check ]]; then report_check; else report_plan; fi
  exit 0
fi

if [[ "$mode" == --install-toolchains ]]; then
  # Re-runnable: only the steps still needed are performed. Runs as the normal user.
  need_manifest
  command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
  [[ "$(id -u)" != 0 ]] || { echo "Toolchains must be installed as a regular user" >&2; exit 1; }
  inspect
  preflight_common
  [[ "$java_major" == "$JAVA_MAJOR" ]] || { echo "Java $JAVA_MAJOR is required (found: ${java_ver:-none})" >&2; exit 1; }
  export PATH="$probe_path"
  cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/bxcachy/external"

  # Download an external installer, show what it is, and run it only after approval:
  # typed EXECUTE when interactive, or --allow-external-scripts when unattended.
  run_external() {  # NAME URL [VAR=VALUE ...]  (extra assignments are passed to the script)
    local name="$1" url="$2" file hash lines answer; shift 2
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
    if ! env "$@" bash "$file"; then echo "$name installer failed (script kept at $file)" >&2; exit 1; fi
  }

  done_any=0
  if (( ! have_mvm )); then
    run_external mvm "$MVM_URL" ${BXCACHY_MVM_VERSION:+MVM_VERSION="$BXCACHY_MVM_VERSION"}; done_any=1
    tool_path mvm >/dev/null || { echo "MVM installation failed: mvm not found afterwards" >&2; exit 1; }
  fi
  if [[ "$(tool_version matchbox)" != "$MATCHBOX_VERSION" ]]; then
    step_retry "mvm install $MATCHBOX_VERSION" mvm install "$MATCHBOX_VERSION"; step_run "mvm use $MATCHBOX_VERSION" mvm use "$MATCHBOX_VERSION"; done_any=1
    [[ "$(tool_version matchbox)" == "$MATCHBOX_VERSION" ]] || { echo "MatchBox $MATCHBOX_VERSION not active after install" >&2; exit 1; }
    echo "MatchBox $MATCHBOX_VERSION installed and verified."
  fi
  if (( ! have_bvm )); then
    run_external bvm "$BVM_URL"; done_any=1
    tool_path bvm >/dev/null || { echo "BVM installation failed: bvm not found afterwards" >&2; exit 1; }
    echo "Note: the BVM installer may add BVM to your shell startup files; open a new shell to pick that up."
  fi
  bl_now="$(bl_version)"; bl_target="$(boxlang_want)"
  if [[ -z "$bl_now" || ( -n "$bl_target" && "$bl_now" != "$bl_target" ) ]]; then
    step_run "bvm install $BOXLANG_VERSION" bvm install "$BOXLANG_VERSION"; step_run "bvm use $BOXLANG_VERSION" bvm use "$BOXLANG_VERSION"; done_any=1
    bl_real="$(tool_version boxlang)"   # the one place the runtime is started: proof that it works
    [[ -n "$bl_real" ]] || { echo "BoxLang does not run after install" >&2; exit 1; }
    [[ -z "$bl_target" || "$bl_real" == "$bl_target" ]] || { echo "BoxLang $bl_target not active after install (found: $bl_real)" >&2; exit 1; }
    echo "BoxLang $bl_real installed and verified."
  elif [[ -z "$bl_target" ]]; then
    echo "BoxLang $bl_now is installed; could not look up the latest version, so it was left as is."
  fi
  if (( ! done_any )); then echo "Nothing to do: MVM, MatchBox $MATCHBOX_VERSION, BVM and BoxLang ${bl_now:-?} are already installed."; fi
  echo "Rust and the bxcachy binary are handled by later steps."
  exit 0
fi

if [[ "$mode" == --install-binary ]]; then
  # Build (or accept) the bxcachy binary, verify it BEFORE touching the installed copy, then replace atomically.
  [[ "$(id -u)" != 0 ]] || { echo "Run as a regular user; no sudo is needed" >&2; exit 1; }
  need_manifest
  work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
  installed="$BIN_DIR/bxcachy"
  check_binary() {  # PATH -> prints its version line; fails unless it identifies itself as BxCachy
    local out; out="$("$1" version 2>&1 | head -n 1)" || true
    [[ "$out" == BxCachy\ * ]] || { echo "Not a working bxcachy binary: $1 (version printed: ${out:-nothing})" >&2; return 1; }
    printf '%s\n' "$out"
  }
  if [[ -n "$binary_arg" ]]; then
    [[ -f "$binary_arg" && -x "$binary_arg" && ! -L "$binary_arg" ]] || { echo "--binary must be an executable regular file (not a symlink): $binary_arg" >&2; exit 1; }
    candidate="$binary_arg"
    new_version="$(check_binary "$candidate")" || exit 1
    if [[ -f "$installed" ]] && cmp -s "$candidate" "$installed" && (( ! force )); then echo "Nothing to do: $installed is identical ($new_version)."; exit 0; fi
  else
    src="$root/src/bxcachy.bxs"
    [[ -n "$root" && -f "$src" ]] || { echo "Source not found ($src). Run this script from a BxCachy checkout, or pass --binary PATH." >&2; exit 1; }
    want="$(grep -m1 -oE 'BxCachy [0-9][0-9A-Za-z.+-]*' "$src" || true)"
    if (( ! force )) && [[ -x "$installed" && -n "$want" ]] && [[ "$(check_binary "$installed" 2>/dev/null || true)" == "$want" ]]; then
      echo "Nothing to do: $installed is already $want (use --force to rebuild)."; exit 0
    fi
    [[ "$(tool_version matchbox)" == "$MATCHBOX_VERSION" ]] || { echo "MatchBox $MATCHBOX_VERSION is required (found: $(tool_version matchbox || true)). Run install.sh --install-toolchains --yes first." >&2; exit 1; }
    cp "$src" "$work/bxcachy.bxs"; chmod 644 "$work/bxcachy.bxs"
    echo "Building bxcachy with MatchBox $MATCHBOX_VERSION"
    if ! ( cd "$work" && PATH="$probe_path" matchbox --target native bxcachy.bxs ) > "$work/build.log" 2>&1; then
      echo "Build failed; the installed copy was not touched. Last lines of the build log:" >&2; tail -n 20 "$work/build.log" >&2; exit 1
    fi
    candidate="$(find "$work" -maxdepth 5 -type f -executable \( -name bxcachy -o -name bxcachy.bxs \) -print -quit)"
    [[ -n "$candidate" ]] || { echo "Build produced no executable; the installed copy was not touched" >&2; tail -n 20 "$work/build.log" >&2; exit 1; }
    new_version="$(check_binary "$candidate")" || { echo "The built binary failed its self-check; the installed copy was not touched" >&2; exit 1; }
  fi
  mkdir -p "$BIN_DIR"
  tmpdest="$(mktemp "$BIN_DIR/.bxcachy.XXXXXX")"
  cp "$candidate" "$tmpdest"; chmod 755 "$tmpdest"; mv -f "$tmpdest" "$installed"
  final="$(check_binary "$installed")" || exit 1
  echo "Installed $installed ($final)"
  case ":$PATH:" in *":$BIN_DIR:"*) ;; *) echo "Note: $BIN_DIR is not on your PATH (see --install for the line to add)." ;; esac
  exit 0
fi

# ---- --install --yes: packages, yay (only if absent), Rust. Runs as the normal user; sudo only for pacman. ----
[[ "$(id -u)" != 0 ]] || { echo "Run as a regular user; sudo is used only for pacman steps" >&2; exit 1; }
# At a terminal pacman shows its own transaction prompt (a full upgrade deserves a second look);
# unattended there is nobody to answer it, and --yes already approved the plan.
pm_flags=(); is_interactive || pm_flags=(--noconfirm)
# box.json needs jq to be read, so jq comes first.
if (( ! manifest_ok )) && ! command -v jq >/dev/null 2>&1; then
  command -v sudo >/dev/null 2>&1 || { echo "sudo is required to install packages but was not found" >&2; exit 1; }
  echo "Installing jq first (needed to read box.json)"
  sudo pacman -S "${pm_flags[@]}" --needed jq || { echo "Could not install jq; nothing else was changed" >&2; exit 1; }
  if load_manifest; then manifest_ok=1; else manifest_ok=0; fi
fi
need_manifest
inspect
preflight_common
if (( ${#missing_pkgs[@]} )) || ! tool_path yay >/dev/null; then
  (( have_sudo )) || { echo "sudo is required to install packages but was not found" >&2; exit 1; }
fi
changed=0
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
  rustup default "$RUST_CHANNEL" || { echo "rustup could not install the stable toolchain" >&2; exit 1; }
  [[ -n "$(tool_version rustc)" ]] || { echo "Rust is still not available after rustup default $RUST_CHANNEL" >&2; exit 1; }
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

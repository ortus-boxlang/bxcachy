#!/usr/bin/env bash
# Runs INSIDE the Arch container as the unprivileged `dev` user.
# Every step is independent: a failure is recorded and the suite continues, so
# one run reports the whole picture. Exit code is 1 if any step failed.
set -uo pipefail
SRC="${SRC:-/src}"
OUT="${OUT:-/out}"
WORK="$HOME/bxcachy"
mkdir -p "$OUT"
rm -rf "$WORK"; cp -a "$SRC" "$WORK"; cd "$WORK"
: > "$OUT/results.tsv"
fails=0

# step NAME EXPECTED_EXIT COMMAND...
step() {
  local name="$1" want="$2"; shift 2
  local start=$SECONDS rc
  { echo "\$ $*"; "$@"; } > "$OUT/$name.log" 2>&1
  rc=$?
  local status=PASS
  [[ "$rc" == "$want" ]] || { status=FAIL; fails=$((fails+1)); }
  printf '%s\t%s\texpected=%s\tgot=%s\t%ss\n' "$status" "$name" "$want" "$rc" "$((SECONDS-start))" | tee -a "$OUT/results.tsv"
}
# Like step, but also requires the log to contain a string.
step_grep() {
  local name="$1" want="$2" needle="$3"; shift 3
  step "$name" "$want" "$@"
  if ! grep -Fq -- "$needle" "$OUT/$name.log"; then
    sed -i "\$s/^PASS/FAIL/" "$OUT/results.tsv"; fails=$((fails+1))
    printf 'FAIL\t%s\toutput missing: %s\n' "$name" "$needle" | tee -a "$OUT/results.tsv"
  fi
}

# GitHub reachability decides whether toolchain/native steps can run. Some sandboxes
# block api.github.com; there they are reported SKIP (never silently PASS). CI runs them.
if curl -fsS -m 15 -o /dev/null https://api.github.com/; then NET=1; else NET=0; fi
skip() { printf 'SKIP\t%s\t%s\n' "$1" "$2" | tee -a "$OUT/results.tsv"; }

export PATH="$HOME/.mvm/bin:$HOME/.cargo/bin:$PATH"

# --- Existing mocked suites, now on real Arch ---
step mock-package-manager 0 bash tests/package-manager-test.sh
step mock-bootstrap       0 bash tests/bootstrap-test.sh
step mock-config          0 bash tests/config-test.sh

# --- CachyOS package sources ---
step cachyos-repos-present 0 bash -c 'for r in cachyos cachyos-v3 cachyos-core-v3 cachyos-extra-v3 cachyos-v4 cachyos-core-v4 cachyos-extra-v4 multilib; do pacman-conf --repo-list | grep -qx "$r" || { echo "missing repo $r"; exit 1; }; done'
step cachyos-stack-resolves 0 bash -c 'for p in cachyos-hypr-noctalia noctalia noctalia-shell hyprland quickshell yay; do pacman -Si "$p" >/dev/null || { echo "unresolved: $p"; exit 1; }; done'

# --- Bootstrap against the real system ---
step bootstrap-check          0 bash bootstrap/install.sh --check
step_grep bootstrap-check-report 0 'summary:' bash bootstrap/install.sh --check
step_grep bootstrap-plan      0 'Read-only plan' bash bootstrap/install.sh --plan
step bootstrap-plan-rejects-args 2 bash bootstrap/install.sh --plan extra
step bootstrap-needs-confirm  2 bash bootstrap/install.sh --install
step_grep bootstrap-install   0 'Next: install.sh --install-toolchains --yes' bash bootstrap/install.sh --install --yes
step_grep bootstrap-install-rerun  0 'Nothing to do for packages, yay and Rust.' bash bootstrap/install.sh --install --yes
step bootstrap-yay-present 0 bash -c 'command -v yay'
step bootstrap-rust-active 0 bash -c 'rustc --version'
step rust-default             0 rustup default stable
# Unattended runs must refuse to execute external installers without the flag (nothing is installed yet here).
step_grep bootstrap-toolchains-refuses-unattended 2 'allow-external-scripts' bash -c 'bash bootstrap/install.sh --install-toolchains --yes </dev/null 2>&1'
if [[ $NET == 1 ]]; then
  step bootstrap-toolchains       0 bash -c 'bash bootstrap/install.sh --install-toolchains --yes --allow-external-scripts </dev/null'
  step_grep bootstrap-toolchains-rerun 0 'Nothing to do' bash -c 'bash bootstrap/install.sh --install-toolchains --yes --allow-external-scripts </dev/null'
  step_grep bootstrap-pins-boxlang   0 'boxlang: 1.19.0' bash bootstrap/install.sh --check
  step_grep bootstrap-pins-matchbox  0 'matchbox: 0.12.0' bash bootstrap/install.sh --check
  # B5: build the real binary with MatchBox and install it for the user.
  step_grep bootstrap-install-binary       0 'Installed '      bash bootstrap/install.sh --install-binary --yes
  step_grep bootstrap-binary-runs          0 'BxCachy 0.'      "$HOME/.local/bin/bxcachy" version
  step_grep bootstrap-install-binary-rerun 0 'Nothing to do'   bash bootstrap/install.sh --install-binary --yes
  step_grep bootstrap-check-binary         0 'bxcachy: 0.'     bash bootstrap/install.sh --check
  step bootstrap-binary-rejects-impostor   1 bash -c 'printf "#!/bin/sh\necho nope\n" > /tmp/impostor; chmod 755 /tmp/impostor; bash bootstrap/install.sh --install-binary --yes --binary /tmp/impostor'
else
  skip bootstrap-toolchains "GitHub unreachable"; skip bootstrap-toolchains-rerun "GitHub unreachable"
fi

# --- Native build ---
BIN=""
if [[ $NET == 1 ]]; then
  step native-compile 0 bash -c 'matchbox --version | grep -F 0.12.0 && matchbox --target native src/bxcachy.bxs'
  BIN="$(find . -maxdepth 5 -type f -executable \( -name bxcachy -o -name 'bxcachy.bxs' \) -print -quit)"
else
  skip native-compile "GitHub unreachable (MatchBox cannot install); native and real-pacman CLI steps skipped"
  BIN=SKIP
fi
if [[ "$BIN" == SKIP ]]; then :
elif [[ -z "$BIN" ]]; then
  echo "FAIL native-binary-found (no executable)" | tee -a "$OUT/results.tsv"; fails=$((fails+1))
else
  BIN="$(realpath "$BIN")"
  step native-smoke       0 bash tests/native-smoke.sh "$BIN"
  step native-mock-install 0 bash tests/native-package-integration.sh "$BIN"

  # --- Real pacman, no mocks ---
  step_grep real-pkg-status-installed   0 "installed"   "$BIN" package-status pacman
  step real-pkg-status-missing          1               "$BIN" package-status bxcachy-no-such-pkg
  step_grep real-pkg-source-installed   0 "installed"   "$BIN" package-source pacman
  step_grep real-pkg-source-official    0 "pacman"      bash -c "sudo pacman -Sy >/dev/null; '$BIN' package-source cowsay"
  step real-pkg-source-unavailable      1               "$BIN" package-source bxcachy-no-such-pkg
  step real-install-no-yes              2               "$BIN" profile-install core
  step real-install-profile-core        0               "$BIN" profile-install core --yes
  step real-install-profile-core-rerun  0               "$BIN" profile-install core --yes
  step_grep real-verify-jq              0 "installed"   "$BIN" package-status jq
  step real-install-optional-official   0               "$BIN" optional-install pinta --yes
fi

# --- Config helper on real filesystem ---
step config-apply-restore 0 bash -c '
  set -e; d=$(mktemp -d); echo one > $d/src; bash scripts/config.sh apply $d/src $d/dst --yes
  echo two > $d/src; bash scripts/config.sh apply $d/src $d/dst --yes
  b=$(ls $d/dst.bxcachy.*.bak | head -1); bash scripts/config.sh restore "$b" $d/dst --yes; grep -Fx one $d/dst'

echo
echo "===== SUMMARY ====="
column -t -s $'\t' "$OUT/results.tsv"
echo "failures: $fails"
[[ "$fails" == 0 ]]

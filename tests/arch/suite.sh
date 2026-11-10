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
  if [[ $status == FAIL ]]; then echo "--- last lines of $name.log:"; tail -n 25 "$OUT/$name.log" | sed 's/^/    | /'; fi
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
# Listing of everything a bootstrap run could change for this user (path, size, mtime), plus the pacman
# log length. Two listings are diffed to prove that a second full run changes nothing.
snaplist() {
  find "$HOME" -path "$WORK" -prune -o -path "$HOME/.cache/bxcachy" -prune -o \( -type f -o -type l \) -printf '%p %s %T@\n' 2>/dev/null | sort
  echo "pacman.log lines: $(wc -l < /var/log/pacman.log 2>/dev/null || echo 0)"
}
skip() { printf 'SKIP\t%s\t%s\n' "$1" "$2" | tee -a "$OUT/results.tsv"; }

export PATH="$HOME/.local/share/bxcachy/matchbox/bin:$HOME/.mvm/bin:$HOME/.cargo/bin:$PATH"

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
step bootstrap-remove-jq    0 sudo pacman -Rdd --noconfirm jq
step_grep bootstrap-check-without-jq 0 'jq is required to read box.json' bash bootstrap/install.sh --check
step bootstrap-toolchains-need-jq 1 bash bootstrap/install.sh --install-toolchains --yes --allow-external-scripts
step_grep bootstrap-install   0 'Installing jq first' bash bootstrap/install.sh --install --yes
step_grep bootstrap-install-completes 0 'Next: install.sh --install-toolchains --yes' bash bootstrap/install.sh --install --yes
step_grep bootstrap-install-rerun  0 'Nothing to do for packages, yay and Rust.' bash bootstrap/install.sh --install --yes
step bootstrap-yay-present 0 bash -c 'command -v yay'
step bootstrap-rust-active 0 bash -c 'rustc --version'
step rust-default             0 rustup default stable
# Unattended runs must refuse to execute external installers without the flag (nothing is installed yet here).
step_grep bootstrap-toolchains-refuses-unattended 2 'allow-external-scripts' bash -c 'bash bootstrap/install.sh --install-toolchains --yes </dev/null 2>&1'
if [[ $NET == 1 ]]; then
  step bootstrap-toolchains       0 bash -c 'bash bootstrap/install.sh --install-toolchains --yes --allow-external-scripts </dev/null'
  step_grep bootstrap-toolchains-rerun 0 'Nothing to do' bash -c 'bash bootstrap/install.sh --install-toolchains --yes --allow-external-scripts </dev/null'
  # BoxLang follows the latest stable release: the installed version must equal what Ortus publishes as latest.
  step bootstrap-boxlang-is-latest   0 bash -c 'want=$(curl -fsS -m 10 https://downloads.ortussolutions.com/ortussolutions/boxlang/version-latest.properties | sed -n "s/^version=\([0-9][0-9.]*\).*/\1/p" | head -1); [ -n "$want" ] && bash bootstrap/install.sh --check | grep -F "boxlang: $want (want latest = $want)"'
  step_grep bootstrap-pins-matchbox  0 "matchbox: $(jq -r .toolchain.matchbox.version box.json)" bash bootstrap/install.sh --check
  step_grep bootstrap-nvm-installed  0 "nvm: 0.41" bash bootstrap/install.sh --check
  step bootstrap-node-installed 0 bash -c "bash bootstrap/install.sh --check | grep -E '^node: [0-9]'"
  # B5: build the real binary with MatchBox and install it for the user.
  step_grep bootstrap-install-binary       0 'Installed '      bash bootstrap/install.sh --install-binary --yes
  step_grep bootstrap-binary-runs          0 'BxCachy 0.'      "$HOME/.local/bin/bxcachy" version
  step_grep bootstrap-install-binary-rerun 0 'Nothing to do'   bash bootstrap/install.sh --install-binary --yes
  step_grep bootstrap-check-binary         0 'bxcachy: 0.'     bash bootstrap/install.sh --check
  step bootstrap-binary-rejects-impostor   1 bash -c 'printf "#!/bin/sh\necho nope\n" > /tmp/impostor; chmod 755 /tmp/impostor; bash bootstrap/install.sh --install-binary --yes --binary /tmp/impostor'
  # B7: the whole path on this clean machine is finished, and running it all again changes nothing.
  step_grep bootstrap-fullpath-ready 0 'summary: ready' env PATH="$HOME/.local/bin:$PATH" bash bootstrap/install.sh --check
  snaplist > "$OUT/snap-before.txt"
  step bootstrap-fullpath-rerun 0 bash -c 'bash bootstrap/install.sh --install --yes </dev/null && bash bootstrap/install.sh --install-toolchains --yes --allow-external-scripts </dev/null && bash bootstrap/install.sh --install-binary --yes </dev/null'
  snaplist > "$OUT/snap-after.txt"
  step bootstrap-fullpath-no-changes 0 bash -c "if diff -u '$OUT/snap-before.txt' '$OUT/snap-after.txt' > '$OUT/snap.diff'; then exit 0; else echo 'the second run changed these:'; grep -E '^[-+][^-+]' '$OUT/snap.diff' | head -40; exit 1; fi"
else
  skip bootstrap-toolchains "GitHub unreachable"; skip bootstrap-toolchains-rerun "GitHub unreachable"
fi

# --- Native build ---
BIN=""
if [[ $NET == 1 ]]; then
  step native-compile 0 bash -c 'matchbox --version | grep -F "$(jq -r .toolchain.matchbox.version box.json)" && matchbox --target native --output bxcachy-built src/Main.bx'
  BIN="$(find . -maxdepth 1 -type f -executable -name bxcachy-built -print -quit)"
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
  step_grep real-pkg-status-installed   0 "installed"   "$BIN" package-status git
  step real-pkg-status-missing          1               "$BIN" package-status yazi
  step real-pkg-status-unknown-id       3               "$BIN" package-status bxcachy-no-such-app
  step_grep real-pkg-source-catalog     0 "pacman"      "$BIN" package-source git
  step_grep real-pkg-source-aur         0 "aur"         "$BIN" package-source vscode
  step real-pkg-source-unknown-id       3               "$BIN" package-source bxcachy-no-such-app
  step_grep real-plan-core              0 "to install"  "$BIN" plan --profile=core
  # setup hyprland: the plan, and every package it names must exist in the real repos (stock Arch plus CachyOS)
  step_grep real-setup-hyprland-plan    0 "Dry run"     "$BIN" setup hyprland --dry-run
  step real-setup-hyprland-packages-exist 0 bash -c "pkgs=\$('$BIN' setup hyprland --dry-run --json | jq -r '.data.steps[0].commands[0][5:][]'); test -n \"\$pkgs\" && sudo pacman -Si \$pkgs >/dev/null"
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

#!/usr/bin/env bash
# `install` end to end with mocked pacman, yay, sudo and id (nothing touches the system).
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
cat > "$tmp/pacman" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  -Qq) exit 0 ;;                                   # nothing installed
  -S) [[ -z "${MOCK_PACMAN_FAIL:-}" ]] || exit 1; printf 'pacman %s\n' "$*" >> "$INSTALL_TEST_LOG" ;;
  *) exit 9 ;;
esac
MOCK
cat > "$tmp/yay" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  --version) echo 'yay mock' ;;
  -S) [[ -z "${MOCK_YAY_FAIL:-}" ]] || exit 1; printf 'yay %s\n' "$*" >> "$INSTALL_TEST_LOG" ;;
  *) exit 9 ;;
esac
MOCK
cat > "$tmp/sudo" <<'MOCK'
#!/usr/bin/env bash
"$@"
MOCK
cat > "$tmp/id" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == -u ]]; then printf '%s\n' "${MOCK_UID:-1000}"; else /usr/bin/id "$@"; fi
MOCK
chmod +x "$tmp/pacman" "$tmp/yay" "$tmp/sudo" "$tmp/id"
export PATH="$tmp:$PATH" INSTALL_TEST_LOG="$tmp/installed.log" HOME="$tmp/home"
mkdir -p "$HOME"
reset() { : > "$INSTALL_TEST_LOG"; }
code() { set +e; "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
reset

# pacman and AUR apps, named: both phases run, exit 0
out="$("$binary" install git vscode --yes 2>&1)" || fail "install git vscode: $out"
grep -Fq 'Installed: git' <<<"$out" || fail 'git reported installed'
grep -Fq 'Installed: vscode' <<<"$out" || fail 'vscode reported installed'
grep -Fq -- 'pacman -S --needed --noconfirm git' "$INSTALL_TEST_LOG" || fail 'pacman call'
grep -Fq -- 'yay -S --needed --noconfirm visual-studio-code-bin' "$INSTALL_TEST_LOG" || fail 'yay call'

# a profile installs its default members
reset
"$binary" profile-install jvm --yes >/dev/null 2>&1 || fail 'profile-install jvm'
for t in jdk21-openjdk maven gradle; do grep -Fq -- "$t" "$INSTALL_TEST_LOG" || fail "jvm profile misses $t"; done

# without --yes: the plan, exit 2, nothing changed; --dry-run: exit 0, nothing changed
reset
[[ "$(code "$binary" install git)" == 2 ]] || fail 'no --yes exits 2'
[[ "$(code "$binary" install git --dry-run)" == 0 ]] || fail '--dry-run exits 0'
[[ "$(code "$binary" install git --dry-run --yes)" == 0 ]] || fail '--dry-run --yes exits 0'
[[ ! -s "$INSTALL_TEST_LOG" ]] || fail 'plan or dry run changed something'
"$binary" install git vscode --dry-run | grep -F 'yay -S' >/dev/null || fail 'dry run prints the exact command'

# root never builds AUR packages, and nothing is changed
reset
[[ "$(MOCK_UID=0 code "$binary" install vscode --yes)" == 4 ]] || fail 'root with AUR exits 4'
[[ ! -s "$INSTALL_TEST_LOG" ]] || fail 'root AUR run changed something'
# root may use pacman directly (no sudo needed)
MOCK_UID=0 "$binary" install git --yes >/dev/null 2>&1 || fail 'root pacman install'

# failures: partial 7, pacman only 5, aur only 6
reset
[[ "$(MOCK_YAY_FAIL=1 code "$binary" install git vscode --yes)" == 7 ]] || fail 'aur failed, pacman done exits 7'
[[ "$(MOCK_PACMAN_FAIL=1 code "$binary" install git --yes)" == 5 ]] || fail 'pacman only failed exits 5'
[[ "$(MOCK_YAY_FAIL=1 code "$binary" install vscode --yes)" == 6 ]] || fail 'aur only failed exits 6'
out="$(MOCK_YAY_FAIL=1 "$binary" install git vscode --yes --json 2>/dev/null || true)"
[[ "$(jq -r '.exit' <<<"$out")" == 7 ]] || fail 'json exit 7'
[[ "$(jq -r '.data.done[0].id' <<<"$out")" == git && "$(jq -r '.data.failed[0].id' <<<"$out")" == vscode ]] || fail 'json done and failed lists'

# bad requests change nothing
reset
[[ "$(code "$binary" install nope-app --yes)" == 2 ]] || fail 'unknown app exits 2'
[[ "$(code "$binary" install intellij --yes)" == 3 ]] || fail 'named unresolved app exits 3'
[[ "$(code "$binary" install git --profile=core --yes)" == 2 ]] || fail 'ids with --profile exit 2'
[[ "$(code "$binary" optional-install --yes)" == 2 ]] || fail 'optional-install needs ids'
[[ ! -s "$INSTALL_TEST_LOG" ]] || fail 'bad request changed something'

# the default tier: web apps and unpinned PKGBUILDs cannot be installed yet, so the run is partial (7)
reset
[[ "$(code "$binary" install --yes)" == 7 ]] || fail 'default install is partial until web apps and pinned PKGBUILDs exist'
grep -Fq neovim "$INSTALL_TEST_LOG" || fail 'default install ran pacman'
echo 'native package integration tests passed'

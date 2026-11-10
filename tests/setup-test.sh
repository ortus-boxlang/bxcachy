#!/usr/bin/env bash
# `bxcachy setup plasma|undo plasma|status` end to end with fake pacman, git, sudo and id. Usage: setup-test.sh [binary]
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home"
cat > "$tmp/bin/pacman" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  -Q) [[ "$2" == kwin ]] && { [[ -n "${MOCK_NO_KWIN:-}" ]] && exit 1; echo "kwin ${MOCK_KWIN:-6.6.2-1}"; } ;;
  -Qq) printf '%s\n' ${MOCK_INSTALLED:-git python-dbus python-gobject qt6-tools} ;;
  -S) [[ -z "${MOCK_PACMAN_FAIL:-}" ]] || exit 1; printf 'pacman %s\n' "$*" >> "$SETUP_LOG" ;;
  *) exit 9 ;;
esac
MOCK
# git clone URL DIR makes a checkout with the three HyprKwin tools; everything they do is logged
cat > "$tmp/bin/git" <<'MOCK'
#!/usr/bin/env bash
printf 'git %s\n' "$*" >> "$SETUP_LOG"
[[ -z "${MOCK_GIT_FAIL:-}" ]] || exit 1
if [[ "$1" == clone ]]; then
  d="${@: -1}"; mkdir -p "$d/tools"
  printf '#!/usr/bin/env bash\n[ -z "$MOCK_INSTALL_FAIL" ] || exit 1\necho "INSTALL in $PWD" >> "$SETUP_LOG"\n' > "$d/tools/install.sh"
  printf '#!/usr/bin/env bash\necho "UNINSTALL in $PWD" >> "$SETUP_LOG"\n' > "$d/tools/uninstall.sh"
  printf 'import os,sys\nopen(os.environ["SETUP_LOG"],"a").write("SHORTCUTS %%s\\n" %% " ".join(sys.argv[1:]))\n' > "$d/tools/hyprkwin-shortcuts.py"
  chmod +x "$d/tools/install.sh" "$d/tools/uninstall.sh"
fi
MOCK
printf '#!/usr/bin/env bash\n[[ "$1" == --version ]] && { echo "Sudo version 1.9"; exit 0; }\n"$@"\n' > "$tmp/bin/sudo"
printf '#!/usr/bin/env bash\nif [[ "$1" == -u ]]; then echo "${MOCK_UID:-1000}"; else /usr/bin/id "$@"; fi\n' > "$tmp/bin/id"
chmod +x "$tmp/bin/"*
export SETUP_LOG="$tmp/setup.log"
run() { env HOME="$tmp/home" PATH="$tmp/bin:$PATH" XDG_CURRENT_DESKTOP=KDE XDG_SESSION_TYPE=wayland SETUP_LOG="$SETUP_LOG" MOCK_INSTALL_FAIL="${MOCK_INSTALL_FAIL:-}" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
reset() { : > "$SETUP_LOG"; rm -rf "$tmp/home/.local"; }
leftovers() { { ls -d /tmp/bxcachy-hyprkwin-* 2>/dev/null || true; } | wc -l; }
before="$(leftovers)"; reset

# gating
[[ "$(code "$binary" setup plasma)" == 2 ]] || fail 'no --yes exits 2'
[[ "$(code "$binary" setup plasma --dry-run)" == 0 ]] || fail '--dry-run exits 0'
[[ ! -s "$SETUP_LOG" ]] || fail 'plan or dry run changed something'
run "$binary" setup plasma --dry-run | grep -F 'tools/install.sh' >/dev/null || fail 'the plan shows the exact command'
[[ "$(MOCK_UID=0 code "$binary" setup plasma --yes)" == 4 ]] || fail 'root exits 4'
[[ "$(MOCK_NO_KWIN=1 code "$binary" setup plasma --yes)" == 4 ]] || fail 'no Plasma exits 4'
[[ "$(MOCK_KWIN=6.4.0-1 code "$binary" setup plasma --yes)" == 4 ]] || fail 'unsupported Plasma exits 4'
[[ "$(env HOME="$tmp/home" PATH="$tmp/bin:$PATH" XDG_CURRENT_DESKTOP=KDE XDG_SESSION_TYPE=x11 SETUP_LOG="$SETUP_LOG" "$binary" setup plasma --yes >/dev/null 2>&1; echo $?)" == 4 ]] || fail 'X11 exits 4'
[[ ! -s "$SETUP_LOG" ]] || fail 'a refused run changed something'

# install
run "$binary" setup plasma --yes >/dev/null 2>&1 || fail 'setup plasma --yes'
grep -Eq '^git clone --quiet https://github.com/DGBooth/HyprKwin.git /tmp/bxcachy-hyprkwin-' "$SETUP_LOG" || fail "clone from the HyprKwin repo (log: $(cat "$SETUP_LOG"))"
grep -Eq '^git -C /tmp/bxcachy-hyprkwin-.* checkout --quiet [0-9a-f]{40}$' "$SETUP_LOG" || fail 'checkout at a full commit'
grep -Eq '^INSTALL in /tmp/bxcachy-hyprkwin-' "$SETUP_LOG" || fail 'install.sh ran inside the checkout'
grep -q SHORTCUTS "$SETUP_LOG" && fail 'keys must stay off by default'
[[ "$(leftovers)" == "$before" ]] || fail 'the temporary checkout was removed'
out="$(run "$binary" setup plasma --dry-run --json)"
[[ "$(jq -r '.data.steps|map(.id)|join(",")' <<<"$out")" == fetch,install ]] || fail 'json steps'
[[ "$(jq -r '.dry_run' <<<"$out")" == true ]] || fail 'json dry_run'

# keys
reset; run "$binary" setup plasma --keys --yes >/dev/null 2>&1 || fail '--keys'
grep -Fq 'SHORTCUTS apply' "$SETUP_LOG" || fail '--keys applies the shortcuts'
reset; [[ "$(code "$binary" setup plasma --undo-keys --yes)" == 4 ]] || fail '--undo-keys needs HyprKwin installed'
mkdir -p "$tmp/home/.local/share/hyprkwin"
run "$binary" setup plasma --undo-keys --yes >/dev/null 2>&1 || fail '--undo-keys'
grep -Fq 'SHORTCUTS restore' "$SETUP_LOG" || fail '--undo-keys restores'
grep -q '^INSTALL' "$SETUP_LOG" && fail '--undo-keys must not reinstall'
[[ "$(code "$binary" setup plasma --keys --undo-keys --yes)" == 4 ]] || fail '--keys with --undo-keys exits 4'

# failures
reset; [[ "$(MOCK_INSTALL_FAIL=1 code "$binary" setup plasma --keys --yes)" == 7 ]] || fail 'install failing after the checkout exits 7'
grep -Fq 'SHORTCUTS' "$SETUP_LOG" && fail 'the keys step must be skipped after a failed install'
out="$(MOCK_INSTALL_FAIL=1 run "$binary" setup plasma --keys --yes --json 2>/dev/null || true)"
[[ "$(jq -r '.data.skipped[0].id' <<<"$out")" == keys-apply && "$(jq -r '.data.failed[0].id' <<<"$out")" == install ]] || fail 'json failed and skipped lists'
reset; [[ "$(MOCK_GIT_FAIL=1 code "$binary" setup plasma --yes)" == 6 ]] || fail 'a failed checkout with nothing done exits 6'
[[ "$(leftovers)" == "$before" ]] || fail 'no checkout left after a failure'

# missing packages go through one sudo pacman call first
reset; out="$(MOCK_INSTALLED=git run "$binary" setup plasma --yes 2>&1)" || fail "install with missing packages: $out"
grep -Fq 'pacman -S --needed --noconfirm python-dbus python-gobject qt6-tools' "$SETUP_LOG" || fail 'one pacman call for the missing packages'
[[ "$(head -n1 "$SETUP_LOG")" == pacman* ]] || fail 'packages come first'
reset; [[ "$(MOCK_INSTALLED=git MOCK_PACMAN_FAIL=1 code "$binary" setup plasma --yes)" == 5 ]] || fail 'pacman failing exits 5'

# undo, status, usage
reset; mkdir -p "$tmp/home/.local/share/hyprkwin"; [[ "$(code "$binary" setup undo plasma --yes)" == 0 ]] || fail 'undo plasma'
grep -Eq '^UNINSTALL in /tmp/bxcachy-hyprkwin-' "$SETUP_LOG" || fail 'undo runs tools/uninstall.sh'
rm -rf "$tmp/home/.local"; [[ "$(code "$binary" setup undo plasma --yes)" == 4 ]] || fail 'undo without HyprKwin exits 4'
[[ "$(run "$binary" setup status --json | jq -r '.data.plasma.kwin')" == 6.6.2 ]] || fail 'status shows the kwin version'
[[ "$(code "$binary" setup)" == 2 ]] || fail 'setup alone is a usage error'
[[ "$(code "$binary" setup nope)" == 2 ]] || fail 'unknown target is a usage error'
[[ "$(code "$binary" setup hyprland --yes)" == 3 ]] || fail 'setup hyprland is not available yet'
echo 'setup tests passed'

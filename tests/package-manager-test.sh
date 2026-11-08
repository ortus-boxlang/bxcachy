#!/usr/bin/env bash
set -euo pipefail
script="$(cd "$(dirname "$0")/.." && pwd)/scripts/package-manager.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/pacman" <<'MOCK'
#!/usr/bin/env bash
case "$1" in -Qq) [[ $2 == mpv ]] ;; -Si) [[ $2 != pacseek ]] ;; -S) printf '%s\n' "$*" >> "$PACMAN_TEST_LOG" ;; *) exit 1 ;; esac
MOCK
cat > "$tmp/sudo" <<'MOCK'
#!/usr/bin/env bash
"$@"
MOCK
chmod +x "$tmp/pacman" "$tmp/sudo"
export PATH="$tmp:$PATH" PACMAN_TEST_LOG="$tmp/install.log"
bash "$script" plan | grep 'mpv: installed'
bash "$script" plan | grep 'pacseek: missing'
if bash "$script" install >/dev/null 2>&1; then echo 'FAIL: missing confirmation' >&2; exit 1; fi
if bash "$script" install --yes >/dev/null 2>&1; then echo 'FAIL: unavailable base package accepted' >&2; exit 1; fi
if [[ -s "$PACMAN_TEST_LOG" ]]; then echo 'FAIL: partial install performed' >&2; exit 1; fi
cat > "$tmp/yay" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  -Si) [[ "$2" == pacseek ]] ;;
  -S) printf 'yay %s\\n' "$*" >> "$PACMAN_TEST_LOG" ;;
  *) exit 1 ;;
esac
MOCK
chmod +x "$tmp/yay"
bash "$script" install --yes >/dev/null
grep -Fq -- '-S --needed localsend' "$PACMAN_TEST_LOG"
grep -Fq -- 'yay -S --needed pacseek' "$PACMAN_TEST_LOG"
if bash "$script" optional-install invalid --yes >/dev/null 2>&1; then echo 'FAIL: invalid optional name accepted' >&2; exit 1; fi
bash "$script" optional-install obs --yes >/dev/null
[[ -s "$PACMAN_TEST_LOG" ]] || { echo 'FAIL: expected optional installation' >&2; exit 1; }
grep -Fq -- '-S --needed obs-studio' "$PACMAN_TEST_LOG"
bash "$script" optional-list | grep 'obs: obs-studio'
echo 'package-manager tests passed'

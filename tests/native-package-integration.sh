#!/usr/bin/env bash
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/pacman" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  -Qq) exit 1 ;;
  -Si) [[ "$2" != pacseek ]] ;;
  -S) printf 'pacman %s\n' "$*" >> "$INSTALL_TEST_LOG" ;;
  *) exit 9 ;;
esac
MOCK
cat > "$tmp/yay" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  -Si) [[ "$2" == pacseek ]] ;;
  -S) printf 'yay %s\n' "$*" >> "$INSTALL_TEST_LOG" ;;
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
export PATH="$tmp:$PATH" INSTALL_TEST_LOG="$tmp/installed.log"
"$binary" install --yes | grep -F 'Installation completed'
grep -Fq -- 'pacman -S --needed --noconfirm localsend mpv' "$INSTALL_TEST_LOG"
grep -Fq -- 'yay -S --needed --noconfirm pacseek' "$INSTALL_TEST_LOG"
: > "$INSTALL_TEST_LOG"
"$binary" profile-install jvm --yes | grep -F 'Installation completed'
grep -Fq -- 'jdk21-openjdk maven gradle' "$INSTALL_TEST_LOG"
: > "$INSTALL_TEST_LOG"
if MOCK_UID=0 "$binary" install --yes >/dev/null 2>&1; then
  echo 'FAIL: root AUR installation accepted' >&2; exit 1
fi
[[ ! -s "$INSTALL_TEST_LOG" ]] || { echo 'FAIL: partial install under root' >&2; exit 1; }
echo 'native package integration tests passed'

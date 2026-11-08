#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/pacman" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  -Qq) [[ "$2" == git ]] ;;
  *) echo "unexpected pacman invocation" >&2; exit 9 ;;
esac
MOCK
cat > "$tmp/sudo" <<'MOCK'
#!/usr/bin/env bash
echo "unexpected sudo invocation" >&2
exit 9
MOCK
chmod +x "$tmp/pacman" "$tmp/sudo"
export PATH="$tmp:$PATH"
bash "$root/bootstrap/install.sh" --check | grep -F 'installed: git'
bash "$root/bootstrap/install.sh" --check | grep -F 'missing: jdk21-openjdk'
if bash "$root/bootstrap/install.sh" --install >/dev/null 2>&1; then
  echo 'FAIL: unattended install without --yes' >&2; exit 1
fi
if bash "$root/bootstrap/install.sh" --unknown >/dev/null 2>&1; then
  echo 'FAIL: invalid bootstrap command accepted' >&2; exit 1
fi
echo 'bootstrap check tests passed'

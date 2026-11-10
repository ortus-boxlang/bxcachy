#!/usr/bin/env bash
# `bxcachy assets list|install`: the embedded images land byte for byte. Usage: assets-test.sh [binary]
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home"
printf '#!/usr/bin/env bash\nif [[ "$1" == -u ]]; then echo "${MOCK_UID:-1000}"; else /usr/bin/id "$@"; fi\n' > "$tmp/bin/id"; chmod +x "$tmp/bin/id"
run() { env HOME="$tmp/home" PATH="$tmp/bin:$PATH" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
run "$binary" assets list | grep -q 'wallpapers/box.jpg -> '"$tmp"'/home/Pictures/BxCachy/box.jpg' || fail 'list shows the targets'
run "$binary" assets list --json | jq -e '(.data.assets | length) == 6' >/dev/null || fail 'list --json'
[[ "$(code "$binary" assets install)" == 2 ]] || fail 'install without --yes exits 2'
[[ "$(code "$binary" assets install --dry-run)" == 0 ]] || fail 'dry run exits 0'
[[ ! -e "$tmp/home/Pictures" ]] || fail 'plan or dry run wrote files'
[[ "$(MOCK_UID=0 code "$binary" assets install --yes)" == 4 ]] || fail 'root exits 4'
[[ "$(code "$binary" assets install --yes)" == 0 ]] || fail 'install --yes exits 0'
for f in wallpapers/box.jpg wallpapers/grid.jpg wallpapers/aurora.jpg wallpapers/minimal.png; do
  cmp "$tmp/home/Pictures/BxCachy/$(basename "$f")" "$root/assets/$f" || fail "$f differs from the source image"
done
cmp "$tmp/home/.local/share/bxcachy/icon.png" "$root/assets/icon.png" || fail 'icon differs'
# a file the user replaced is kept
echo mine > "$tmp/home/Pictures/BxCachy/box.jpg"
[[ "$(code "$binary" assets install --yes)" == 0 ]] || fail 're-run exits 0'
[[ "$(cat "$tmp/home/Pictures/BxCachy/box.jpg")" == mine ]] || fail 'a changed wallpaper was overwritten'
[[ -z "$(ls "$tmp/home/Pictures/BxCachy" | grep '\.b64$' || true)" ]] || fail 'temp .b64 left behind'
echo "assets tests passed"

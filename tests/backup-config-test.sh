#!/usr/bin/env bash
# `bxcachy backup config ...` with a temp home, fake pacman, sudo and a fake bxcachy. Usage: backup-config-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
H="$tmp/home"; mkdir -p "$tmp/bin" "$H/.config/hypr" "$H/.config/bxcachy" "$H/.config/nvim/.git" "$H/.ssh" "$H/.config/zed"; export LOG="$tmp/log"; : > "$LOG"
echo 'hl config' > "$H/.config/hypr/hyprland.lua"; echo '{"a":1}' > "$H/.config/bxcachy/answers.json"; echo 'export A=1' > "$H/.zshrc"
echo 'init' > "$H/.config/nvim/init.lua"; echo 'gitstuff' > "$H/.config/nvim/.git/HEAD"
echo 'Host x' > "$H/.ssh/config"; echo 'PRIVATE KEY' > "$H/.ssh/id_ed25519"; echo 'zed' > "$H/.config/zed/settings.json"
cat > "$tmp/bin/pacman" <<'F'
#!/usr/bin/env bash
echo "pacman $*" >> "$LOG"
case "$1" in
  -Qqe) printf '%b\n' "${PKGS:-git\nneovim\nripgrep\nyay-bin}" ;;
  -Qqm) printf 'yay-bin\n' ;;
  -Qq) printf 'git\nneovim\n' ;;
esac
exit 0
F
printf '#!/usr/bin/env bash\n[[ "$1" == --version ]] && { echo "Sudo version 1.9"; exit 0; }\necho "sudo $*" >> "$LOG"\nexit 0\n' > "$tmp/bin/sudo"
printf '#!/usr/bin/env bash\necho "self $*" >> "$LOG"\nif [[ "$2" == export ]]; then echo "encrypted" > "$3"; fi\n' > "$tmp/self"
printf '#!/usr/bin/env bash\nif [[ "$1" == -u ]]; then echo 1000; else /usr/bin/id "$@"; fi\n' > "$tmp/bin/id"
chmod +x "$tmp/bin"/* "$tmp/self"
run() { env HOME="$H" BXCACHY_CONFIG_HOME="$H/.config" BXCACHY_DATA_HOME="$tmp/data" BXCACHY_SELF="$tmp/self" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
has() { grep -qF -- "$1" "$LOG"; }

run "$binary" backup config list --json | jq -e '.data.snapshots == []' >/dev/null || fail 'starts empty'
[[ "$(code "$binary" backup nonsense)" == 2 && "$(code "$binary" backup config nonsense)" == 2 ]] || fail 'usage exits 2'

# ---- now ----
id1="$(run "$binary" backup config now --reason=first --json | jq -r '.data.snapshot.id')"; [[ "$id1" =~ ^[0-9]{8}T[0-9]{6}$ ]] || fail "snapshot id: $id1"
a="$tmp/data/backups/config/$id1.tar.gz"; [[ -s "$a" && "$(stat -c %a "$a")" == 600 ]] || fail 'archive missing or not private'
tar -tzf "$a" > "$tmp/list"
grep -q '^./files/.zshrc$' "$tmp/list" && grep -q '^./files/.config/hypr/hyprland.lua$' "$tmp/list" && grep -q '^./files/.config/nvim/init.lua$' "$tmp/list" && grep -q '^./files/.ssh/config$' "$tmp/list" || fail "files in the snapshot: $(cat "$tmp/list")"
grep -q '/.git' "$tmp/list" && fail '.git was included'
grep -q 'id_ed25519' "$tmp/list" && fail 'an SSH key was included'
grep -q 'zed' "$tmp/list" && fail 'an untracked folder was included'
tar -xzOf "$a" ./packages.txt | grep -qx 'ripgrep' && tar -xzOf "$a" ./foreign.txt | grep -qx 'yay-bin' || fail 'package lists'
tar -xzOf "$a" ./meta.json | jq -e '.reason == "first" and .secrets == false and .packages == 4' >/dev/null || fail 'meta'
run "$binary" backup config list | grep -q "$id1   first" || fail 'list shows it'

# ---- tracked paths ----
run "$binary" backup config add .config/zed >/dev/null; run "$binary" backup config paths --json | jq -e '.data.paths | index(".config/zed") != null' >/dev/null || fail 'add a path'
[[ "$(code "$binary" backup config add .ssh/id_ed25519)" == 2 && "$(code "$binary" backup config add ../etc)" == 2 && "$(code "$binary" backup config add /etc/passwd)" == 2 ]] || fail 'keys, .. and absolute paths are refused'
run "$binary" backup config remove .zshrc >/dev/null; run "$binary" backup config paths --json | jq -e '.data.paths | index(".zshrc") == null' >/dev/null || fail 'remove a default path'

# ---- with secrets ----
id2="$(run "$binary" backup config now --with-secrets --json | jq -r '.data.snapshot.id')"
tar -tzf "$tmp/data/backups/config/$id2.tar.gz" | grep -q '^./secrets.bxs$' && has 'self secrets export' || fail 'the secrets bundle is included only on request'
tar -tzf "$tmp/data/backups/config/$id2.tar.gz" | grep -q 'zed/settings.json' || fail 'the added path is in the next snapshot'
run "$binary" backup config paths add .zshrc >/dev/null 2>&1 || run "$binary" backup config add .zshrc >/dev/null

# ---- diff ----
run "$binary" backup config diff "$id1" --json | jq -e '[.data.files[] | select(.state != "same")] | length == 0' >/dev/null || fail 'nothing changed yet'
echo 'edited' >> "$H/.config/hypr/hyprland.lua"; rm "$H/.zshrc"
PKGS='git\nneovim' run "$binary" backup config diff "$id1" --json | jq -e '(.data.files | map(select(.file == ".config/hypr/hyprland.lua" and .state == "changed")) | length == 1) and (.data.files | map(select(.file == ".zshrc" and .state == "missing")) | length == 1) and (.data.missing_packages == ["ripgrep","yay-bin"])' >/dev/null || fail "diff: $(run "$binary" backup config diff "$id1")"
[[ "$(code "$binary" backup config diff 20000101T000000)" == 4 ]] || fail 'unknown id exits 4'

# ---- restore: a plan, then the files, with a safety snapshot ----
[[ "$(code "$binary" backup config restore "$id1")" == 2 ]] || fail 'restore without --yes is a plan'
grep -q edited "$H/.config/hypr/hyprland.lua" || fail 'the plan changed a file'
run "$binary" backup config restore "$id1" --dry-run | grep -q 'replace  ~/.config/hypr/hyprland.lua' || fail 'plan lists files'
before="$(run "$binary" backup config list --json | jq '.data.snapshots | length')"
run "$binary" backup config restore "$id1" --only=.config/hypr --yes --json | jq -e '.ok and (.data.restored == [".config/hypr/hyprland.lua"]) and (.data.safety | length > 0)' >/dev/null || fail 'restore --only'
grep -qx 'hl config' "$H/.config/hypr/hyprland.lua" || fail 'the file was restored'
[[ ! -e "$H/.zshrc" ]] || fail '--only restored something else'
[[ "$(run "$binary" backup config list --json | jq '.data.snapshots | length')" == $((before + 1)) ]] || fail 'a safety snapshot was taken'
: > "$LOG"; run "$binary" backup config restore "$id1" --packages --yes >/dev/null
grep -q 'export A=1' "$H/.zshrc" || fail 'the missing file came back'
has 'sudo pacman -S --needed --noconfirm ripgrep' || fail "packages: $(cat "$LOG")"
! has 'yay-bin' || fail 'a foreign package was installed through pacman'

# ---- auto and prune ----
run "$binary" backup config auto status --json | jq -e '.data.auto == true' >/dev/null || fail 'auto is on by default'
run "$binary" backup config auto off >/dev/null; run "$binary" backup config auto status --json | jq -e '.data.auto == false' >/dev/null || fail 'auto off'
n="$(run "$binary" backup config list --json | jq '.data.snapshots | length')"
run "$binary" system update --dry-run >/dev/null 2>&1 || true
[[ "$(run "$binary" backup config list --json | jq '.data.snapshots | length')" == "$n" ]] || fail 'a dry run took a snapshot'
run "$binary" backup config auto on >/dev/null
n="$(run "$binary" backup config list --json | jq '.data.snapshots | length')"
run "$binary" refresh theme --yes >/dev/null 2>&1 || true
[[ "$(run "$binary" backup config list --json | jq '.data.snapshots | length')" == $((n + 1)) ]] || fail 'refresh --yes did not take a snapshot first'
run "$binary" backup config list --json | jq -e '.data.snapshots[0].reason == "before refresh theme"' >/dev/null || fail 'the snapshot says why'
[[ "$(code "$binary" backup config prune --keep=2)" == 2 ]] || fail 'prune without --yes is a plan'
run "$binary" backup config prune --keep=2 --yes >/dev/null; [[ "$(run "$binary" backup config list --json | jq '.data.snapshots | length')" == 2 ]] || fail 'prune keeps the newest N'
ls "$tmp/data/backups/config" | grep -c json | grep -qx 2 || fail 'prune removed the files too'
echo "backup-config-test: ok"

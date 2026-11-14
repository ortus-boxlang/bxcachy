#!/usr/bin/env bash
# `bxrig containers` and `bxrig editor lazyvim` with fake podman, docker, pacman, sudo, systemctl and git. Usage: containers-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/etc" "$tmp/installed"; export LOG="$tmp/log"; : > "$LOG"
printf '#!/usr/bin/env bash\necho "podman $*" >> "$LOG"\n[[ "$1" == info ]] && echo "${ROOTLESS:-true}"\n' > "$tmp/bin/podman"
printf '#!/usr/bin/env bash\necho "podman version 6.2.0"\n' > "$tmp/bin/docker"
printf '#!/usr/bin/env bash\necho "systemctl $*" >> "$LOG"\n[[ "$2" == is-active ]] && echo "${SOCK:-inactive}"\nexit 0\n' > "$tmp/bin/systemctl"
printf '#!/usr/bin/env bash\necho "sudo $*" >> "$LOG"\nexec "$@"\n' > "$tmp/bin/sudo"
cat > "$tmp/bin/pacman" <<'SH'
#!/usr/bin/env bash
echo "pacman $*" >> "$LOG"
if [[ "$1" == -Q ]]; then [[ -e "$INSTALLED/$2" ]]; exit $?; fi
if [[ "$1" == -S ]]; then for a in "$@"; do [[ "$a" != -* ]] && touch "$INSTALLED/$a"; done; fi
SH
printf '#!/usr/bin/env bash\necho "git $*" >> "$LOG"\nif [[ "$1" == clone ]]; then mkdir -p "$3/.git" "$3/lua"; echo init > "$3/init.lua"; fi\n' > "$tmp/bin/git"
chmod +x "$tmp/bin"/*
run() { env HOME="$tmp/home" USER=ada BXRIG_ETC="$tmp/etc" XDG_RUNTIME_DIR=/run/user/1000 XDG_CONFIG_HOME="$tmp/home/.config" INSTALLED="$tmp/installed" LOG="$LOG" ROOTLESS="${ROOTLESS:-true}" SOCK="${SOCK:-}" PATH="$tmp/bin:$PATH" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

# doctor: everything missing it can fix is reported with the command that fixes it
echo "ada:100000:65536" > "$tmp/etc/subuid"; echo "ada:100000:65536" > "$tmp/etc/subgid"
out="$(run "$binary" containers doctor)" && fail 'doctor must exit 4 while something needs fixing' || true
[[ "$out" == *'FIX   compose'* && "$out" == *'bxrig containers docker-compat'* && "$out" == *'FIX   socket'* && "$out" == *'ok    docker-shim'* && "$out" == *'ok    subuid'* && "$out" == *'ok    rootless'* ]] || fail "doctor report: $out"
touch "$tmp/installed/x"; ln -sf "$tmp/bin/podman" "$tmp/bin/podman-compose"
SOCK=active run "$binary" containers doctor --json | jq -e '.ok == true and (.data.checks | length) == 6' >/dev/null || fail "doctor when all is well: $(SOCK=active run "$binary" containers doctor --json)"
{ ROOTLESS=false SOCK=active run "$binary" containers doctor --json || true; } | jq -e '.data.checks[] | select(.id=="rootless") | .ok == false' >/dev/null || fail 'doctor rootless'
rm "$tmp/etc/subuid"; { SOCK=active run "$binary" containers doctor --json || true; } | jq -e '.data.checks[] | select(.id=="subuid") | .ok == false and (.fix | contains("usermod"))' >/dev/null || fail 'doctor subuid'
mkdir -p "$tmp/nobin"; ln -sf "$(command -v sh)" "$tmp/nobin/sh"
set +e; env HOME="$tmp/home" PATH="$tmp/nobin" "$binary" containers doctor >/dev/null 2>&1; rc=$?; set -e; [[ "$rc" == 4 ]] || fail 'no podman exits 4'

# socket
[[ "$(code "$binary" containers socket enable)" == 2 ]] || fail 'socket enable without --yes exits 2'
: > "$LOG"; run "$binary" containers socket enable --yes | grep -q 'DOCKER_HOST=unix:///run/user/1000/podman/podman.sock' || fail 'socket enable prints DOCKER_HOST'
grep -q 'systemctl --user enable --now podman.socket' "$LOG" || fail 'socket command'

# docker-compat
rm -f "$tmp/installed/"*
[[ "$(code "$binary" containers docker-compat)" == 2 ]] || fail 'docker-compat without --yes exits 2'
: > "$LOG"; run "$binary" containers docker-compat --yes | grep -q 'Installed podman-docker, podman-compose' || fail 'docker-compat --yes'
grep -q 'sudo pacman -S --needed --noconfirm podman-docker podman-compose' "$LOG" || fail "install command: $(cat "$LOG")"
run "$binary" containers docker-compat --yes | grep -q 'Already in place' || fail 'docker-compat is idempotent'
touch "$tmp/installed/docker"; rm -f "$tmp/installed/podman-docker"; [[ "$(code "$binary" containers docker-compat --yes)" == 4 ]] || fail 'the docker package blocks podman-docker (exit 4)'
rm -f "$tmp/installed/docker"

# LazyVim
rm -f "$tmp/installed/"*
[[ "$(code "$binary" editor lazyvim)" == 2 ]] || fail 'lazyvim without --yes exits 2'
[[ ! -e "$tmp/home/.config/nvim" ]] || fail 'the plan cloned'
: > "$LOG"; run "$binary" editor lazyvim --yes | grep -q 'LazyVim starter is in' || fail 'lazyvim --yes'
grep -q 'sudo pacman -S --needed --noconfirm neovim git ripgrep fd lazygit' "$LOG" || fail "tools installed first: $(cat "$LOG")"
grep -q "git clone https://github.com/LazyVim/starter $tmp/home/.config/nvim" "$LOG" || fail 'clone command'
[[ -f "$tmp/home/.config/nvim/init.lua" && ! -e "$tmp/home/.config/nvim/.git" ]] || fail 'the .git folder is removed'
echo mine > "$tmp/home/.config/nvim/init.lua"; : > "$LOG"
[[ "$(code "$binary" editor lazyvim --yes)" == 4 ]] || fail 'an existing nvim config exits 4'
[[ "$(cat "$tmp/home/.config/nvim/init.lua")" == mine && ! -s "$LOG" ]] || fail 'an existing config was touched'
echo "containers-test: ok"

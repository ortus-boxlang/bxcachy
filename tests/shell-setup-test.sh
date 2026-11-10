#!/usr/bin/env bash
# `bxcachy setup shell` end to end with fake pacman, sudo, id, chsh: packages, Starship + shell config, login shell. Usage: shell-setup-test.sh [binary]
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home"
export LOG="$tmp/log"; : > "$LOG"
cat > "$tmp/bin/pacman" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  -Q) exit 1 ;;
  -Qq) true ;;
  -S) echo "pacman $*" >> "$LOG" ;;
  --version) echo "Pacman v7.0" ;;
  *) exit 9 ;;
esac
MOCK
printf '#!/usr/bin/env bash\necho "chsh $*" >> "$LOG"\n' > "$tmp/bin/chsh"
printf '#!/usr/bin/env bash\n[[ "$1" == --version ]] && { echo "Sudo version 1.9"; exit 0; }\n"$@"\n' > "$tmp/bin/sudo"
printf '#!/usr/bin/env bash\nif [[ "$1" == -u ]]; then echo "${MOCK_UID:-1000}"; else /usr/bin/id "$@"; fi\n' > "$tmp/bin/id"
printf '#!/usr/bin/env bash\necho x86_64\n' > "$tmp/bin/uname"
chmod +x "$tmp/bin/"*
printf 'ID=cachyos\n' > "$tmp/os"
run() { env BXCACHY_OS_RELEASE="$tmp/os" BXCACHY_STATE_HOME="$tmp/state" BXCACHY_CONFIG_HOME="$tmp/cfg" HOME="$tmp/home" USER=dev SHELL="${LOGIN_SHELL:-/usr/bin/fish}" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

# plan only: nothing written; zsh is the default
[[ "$(code "$binary" setup shell)" == 2 ]] || fail 'no --yes exits 2'
[[ ! -e "$tmp/cfg" && ! -e "$tmp/home/.zshrc" ]] || fail 'the plan wrote files'
run "$binary" setup shell --dry-run --json | jq -e '.ok and (.data.steps | map(.id) == ["packages","config","login"]) and (.data.steps[0].commands[0] | join(" ") | test("zsh zsh-autosuggestions zsh-syntax-highlighting zsh-completions starship fzf zoxide")) and (.data.steps[2].commands[0] | join(" ") == "sudo chsh -s /usr/bin/zsh dev")' >/dev/null || fail 'default plan is zsh with the plugins, Starship, and chsh'
[[ "$(code "$binary" setup shell --shell=tcsh --yes)" == 4 ]] || fail 'an unknown shell exits 4'

# apply zsh: the user's own .zshrc keeps its content and gets one block
printf '# my zshrc\nalias ll="ls -l"\n' > "$tmp/home/.zshrc"
out="$(run "$binary" setup shell --yes --json)" || fail "setup shell --yes failed: $out"
echo "$out" | jq -e '.ok and (.data.done | map(.id) == ["packages","config","login"])' >/dev/null || fail "all three steps done: $out"
grep -q 'pacman -S --needed --noconfirm zsh zsh-autosuggestions' "$LOG" || fail 'packages installed'
grep -q 'chsh -s /usr/bin/zsh dev' "$LOG" || fail 'login shell changed'
grep -q '^# my zshrc' "$tmp/home/.zshrc" && grep -q 'alias ll=' "$tmp/home/.zshrc" || fail 'user .zshrc content lost'
[[ "$(grep -c '>>> bxcachy shell' "$tmp/home/.zshrc")" == 1 ]] || fail 'exactly one block in .zshrc'
grep -q "source \"$tmp/cfg/bxcachy/shell.zsh\"" "$tmp/home/.zshrc" || fail 'block sources the managed init'
grep -q 'starship init zsh' "$tmp/cfg/bxcachy/shell.zsh" && grep -q 'zsh-autosuggestions.zsh' "$tmp/cfg/bxcachy/shell.zsh" && grep -q 'zsh-syntax-highlighting.zsh' "$tmp/cfg/bxcachy/shell.zsh" || fail 'zsh init has starship and the plugins'
grep -q 'bold #00ff78' "$tmp/cfg/starship.toml" || fail 'starship config written'

# again: nothing duplicated, a changed starship.toml is kept
echo '# mine' >> "$tmp/cfg/starship.toml"
LOGIN_SHELL=/usr/bin/zsh run "$binary" setup shell --yes --json | jq -e '.ok and (.data.done | map(.id) == ["packages","config"])' >/dev/null || fail 'second run has no login step (already zsh)'
[[ "$(grep -c '>>> bxcachy shell' "$tmp/home/.zshrc")" == 1 ]] || fail 'block added twice'
grep -q '^# mine' "$tmp/cfg/starship.toml" || fail 'edited starship.toml was overwritten'

# fish: conf.d file, no rc edit; bash: rc block
rm -rf "$tmp/cfg" "$tmp/home/.zshrc"
LOGIN_SHELL=/usr/bin/bash run "$binary" setup shell --shell=fish --yes >/dev/null || fail 'fish failed'
grep -q 'starship init fish' "$tmp/cfg/fish/conf.d/bxcachy.fish" || fail 'fish conf.d written'
[[ ! -e "$tmp/home/.zshrc" && ! -e "$tmp/home/.bashrc" ]] || fail 'fish must not touch an rc file'
LOGIN_SHELL=/usr/bin/bash run "$binary" setup shell --shell=bash --yes >/dev/null || fail 'bash failed'
grep -q 'starship init bash' "$tmp/cfg/bxcachy/shell.bash" || fail 'bash init written'
grep -q '>>> bxcachy shell' "$tmp/home/.bashrc" || fail 'bash rc block written'
echo "shell setup tests passed"

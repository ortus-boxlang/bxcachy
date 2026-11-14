#!/usr/bin/env bash
# `bxrig dotfiles` end to end: real git repos on disk, a throwaway home directory, fake stow/chezmoi/yadm/pacman. Usage: dotfiles-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
mkdir -p "$tmp/bin"; export LOG="$tmp/log"; : > "$LOG"
for tool in stow chezmoi yadm; do printf '#!/usr/bin/env bash\necho "%s $*" >> "$LOG"\n' "$tool" > "$tmp/fake-$tool"; chmod +x "$tmp/fake-$tool"; done
# fake pacman -S installs the fake tool of that name; sudo just runs its arguments
printf '#!/usr/bin/env bash\nif [[ "$1" == -S ]]; then echo "pacman $*" >> "$LOG"; cp "$FAKE_TOOLS/fake-${@: -1}" "$FAKE_BIN/${@: -1}"; fi\n' > "$tmp/bin/pacman"
printf '#!/usr/bin/env bash\n[[ "$1" == --version ]] && { echo "Sudo version 1.9"; exit 0; }\n"$@"\n' > "$tmp/bin/sudo"
chmod +x "$tmp/bin/pacman" "$tmp/bin/sudo"
export FAKE_TOOLS="$tmp" FAKE_BIN="$tmp/bin"

# a repo: mkrepo NAME FILE... (each FILE is created with its own path as content)
mkrepo() { local r="$tmp/repos/$1"; shift; mkdir -p "$r"; git -C "$r" init -q; for f in "$@"; do mkdir -p "$r/$(dirname "$f")"; echo "repo:$f" > "$r/$f"; done; git -C "$r" add -A; git -C "$r" commit -qm init; }
# a fresh home and data folder for each scenario
fresh() { rm -rf "$tmp/home" "$tmp/data" "$tmp/state" "$tmp/cfg"; mkdir -p "$tmp/home"; }
run() { env HOME="$tmp/home" BXRIG_DATA_HOME="$tmp/data" BXRIG_STATE_HOME="$tmp/state" BXRIG_CONFIG_HOME="$tmp/cfg" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
df() { run "$binary" dotfiles "$@"; }
home="$tmp/home"

mkrepo links .zshrc .config/hypr/hyprland.lua .config/app/x.conf README.md .gitignore
mkrepo chezmoi dot_zshrc dot_config/app/x.conf private_dot_ssh/config.tmpl README.md
mkrepo yadm .bashrc '.config/yadm/bootstrap' '.gitconfig##os.Linux'
mkrepo stow zsh/.zshrc git/.gitconfig README.md
mkrepo empty README.md

# ---- detection ----
fresh; for pair in links:links chezmoi:chezmoi yadm:yadm stow:stow; do
  name="${pair%%:*}"; want="${pair##*:}"; rm -rf "$tmp/data"
  [[ "$(df plan "$tmp/repos/$name" --json | jq -r .data.detected)" == "$want" ]] || fail "$name should be detected as $want"
done
rm -rf "$tmp/data"; [[ "$(df plan "$tmp/repos/chezmoi" --method=links --json | jq -r .data.method)" == links ]] || fail '--method overrides the detection' 
rm -rf "$tmp/data"
[[ "$(code "$binary" dotfiles plan "$tmp/repos/links" --method=nope)" == 4 ]] || fail 'an unknown method exits 4'
rm -rf "$tmp/data"; [[ "$(code "$binary" dotfiles plan "$tmp/repos/empty")" == 4 ]] || fail 'a repo with nothing to apply exits 4'
rm -rf "$tmp/data"; [[ "$(code "$binary" dotfiles plan "$tmp/repos/missing")" == 4 ]] || fail 'a repo that cannot be cloned exits 4'

# ---- links: the plan lists conflicts and changes nothing ----
fresh; mkdir -p "$home/.config"; echo mine > "$home/.zshrc"
out="$(df plan "$tmp/repos/links" --json)"
echo "$out" | jq -e '.data.method == "links" and .data.total == 3 and (.data.conflicts | length) == 1 and (.data.conflicts[0] | endswith("/.zshrc")) and (.data.fresh | length) == 2' >/dev/null || fail "links plan: $out"
[[ "$(cat "$home/.zshrc")" == mine && ! -e "$home/.config/hypr" ]] || fail 'the plan changed the home directory'
df plan "$tmp/repos/links" | grep -q 'Your dotfiles win' || fail 'the plan says whose files win'
[[ "$(code "$binary" dotfiles apply "$tmp/repos/links")" == 2 ]] || fail 'apply without --yes exits 2'
df apply "$tmp/repos/links" --dry-run | grep -q 'Nothing was changed' || fail 'dry-run'
# conflicts need approval: no terminal means no
rc=0; BXRIG_TTY_IN="$tmp/none" df apply "$tmp/repos/links" --yes >/dev/null 2>&1 || rc=$?
[[ "$rc" == 2 && "$(cat "$home/.zshrc")" == mine && ! -e "$home/.config/hypr" ]] || fail "unapproved conflicts must change nothing (rc=$rc)"
printf 'n\n' > "$tmp/tty"; rc=0; BXRIG_TTY_IN="$tmp/tty" df apply "$tmp/repos/links" --yes >/dev/null 2>&1 || rc=$?
[[ "$rc" == 2 && "$(cat "$home/.zshrc")" == mine ]] || fail 'answering n changes nothing'
# approved at the prompt
printf 'y\n' > "$tmp/tty"
BXRIG_TTY_IN="$tmp/tty" df apply "$tmp/repos/links" --yes --json | jq -e '.ok and .data.applied and (.data.backups | length) == 1' >/dev/null || fail 'apply approved at the prompt'
[[ -L "$home/.zshrc" && "$(cat "$home/.zshrc")" == 'repo:.zshrc' ]] || fail '.zshrc is now a link to the repo file'
[[ -L "$home/.config/hypr/hyprland.lua" && -L "$home/.config/app/x.conf" ]] || fail 'the other files are linked'
[[ ! -e "$home/README.md" && ! -e "$home/.gitignore" ]] || fail 'repo-only files must not be linked'
bk="$(find "$tmp/state/bxrig/backups/dotfiles" -name .zshrc 2>/dev/null | head -1)"; [[ -n "$bk" && "$(cat "$bk")" == mine ]] || fail 'the original .zshrc is backed up'
df status | grep -q '3 links, 1 original files backed up' || fail 'status'
# again: everything is in place, nothing to ask
df apply "$tmp/repos/links" --yes --json | jq -e '.ok and (.data.same | length) == 3 and (.data.conflicts | length) == 0' >/dev/null || fail 're-apply finds everything in place'
# undo puts the original back
[[ "$(code "$binary" dotfiles undo)" == 2 ]] || fail 'undo without --yes exits 2'
out="$(df undo --yes)"; [[ "$out" == *'Removed 3 links and restored 1'* ]] || fail "undo: $out"
[[ ! -L "$home/.zshrc" && "$(cat "$home/.zshrc")" == mine && ! -e "$home/.config/hypr/hyprland.lua" ]] || fail 'undo restores the original and removes the links'
df status | grep -q 'No dotfiles have been applied' || fail 'status after undo'
[[ "$(code "$binary" dotfiles undo --yes)" == 4 ]] || fail 'undo with nothing applied exits 4'

# --overwrite approves without a prompt
fresh; echo mine > "$home/.zshrc"
BXRIG_TTY_IN="$tmp/none" df apply "$tmp/repos/links" --yes --overwrite >/dev/null || fail '--overwrite'
[[ -L "$home/.zshrc" ]] || fail '--overwrite applies'
# a different repo cannot take the slot
[[ "$(code "$binary" dotfiles plan "$tmp/repos/stow")" == 4 ]] || fail 'a second repo is refused until the first is undone'

# ---- chezmoi: names are mapped, the tool applies ----
fresh; echo old > "$home/.zshrc"
out="$(df plan "$tmp/repos/chezmoi" --json)"
echo "$out" | jq -e '.data.method == "chezmoi" and ([.data.fresh[], .data.conflicts[]] | map(select(endswith("/.zshrc") or endswith("/.config/app/x.conf") or endswith("/.ssh/config"))) | length) == 3 and .data.install_tool == true' >/dev/null || fail "chezmoi mapping and tool install: $out"
: > "$LOG"; df apply "$tmp/repos/chezmoi" --yes --overwrite >/dev/null || fail 'chezmoi apply'
grep -q 'pacman -S --needed --noconfirm chezmoi' "$LOG" || fail 'chezmoi is installed first'
grep -q "chezmoi apply --source $tmp/data/dotfiles/repo --force" "$LOG" || fail "chezmoi runs against the clone: $(cat "$LOG")"
[[ "$(cat "$(find "$tmp/state/bxrig/backups/dotfiles" -name .zshrc | head -1)")" == old ]] || fail 'chezmoi: the original is backed up before the tool runs'

# ---- yadm ----
fresh; echo "repo:.bashrc" > "$home/.bashrc"; echo different > "$home/.gitconfig"; cp "$tmp/fake-yadm" "$tmp/bin/yadm"
out="$(df plan "$tmp/repos/yadm" --json)"
echo "$out" | jq -e '.data.method == "yadm" and (.data.same | length) == 1 and (.data.conflicts | length) == 1 and (.data.conflicts[0] | endswith("/.gitconfig"))' >/dev/null || fail "yadm: identical files are not conflicts, ## names map to the plain name: $out"
: > "$LOG"; df apply "$tmp/repos/yadm" --yes --overwrite >/dev/null || fail 'yadm apply'
grep -q "yadm clone -f --no-bootstrap $tmp/repos/yadm" "$LOG" || fail "yadm clone: $(cat "$LOG")"
rm -f "$tmp/bin/yadm"

# ---- stow ----
fresh; mkdir -p "$home"; echo x > "$home/.zshrc"
out="$(df plan "$tmp/repos/stow" --json)"
echo "$out" | jq -e '.data.method == "stow" and .data.total == 2 and (.data.conflicts | length) == 1 and .data.install_tool == true' >/dev/null || fail "stow plan: $out"
: > "$LOG"; df apply "$tmp/repos/stow" --yes --overwrite >/dev/null || fail 'stow apply'
grep -q 'pacman -S --needed --noconfirm stow' "$LOG" && grep -Eq "stow -d $tmp/data/dotfiles/repo -t $home -R (git zsh|zsh git)" "$LOG" || fail "stow runs with its packages: $(cat "$LOG")"
df undo --yes >/dev/null || fail 'stow undo'
grep -Eq "stow -d .* -t $home -D" "$LOG" || fail 'undo runs stow -D'
[[ "$(cat "$home/.zshrc")" == x ]] || fail 'stow: the original comes back'
rm -f "$tmp/bin/stow"

# a failing tool rolls the backups back
fresh; echo keep > "$home/.zshrc"; printf '#!/usr/bin/env bash\nexit 1\n' > "$tmp/bin/stow"; chmod +x "$tmp/bin/stow"
rc=0; df apply "$tmp/repos/stow" --yes --overwrite >/dev/null 2>&1 || rc=$?
[[ "$rc" == 6 && "$(cat "$home/.zshrc")" == keep ]] || fail "a failing stow exits 6 and puts the original back (rc=$rc)"
echo "dotfiles tests passed"

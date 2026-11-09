#!/usr/bin/env bash
# Read-only package commands on the catalog, with a fake pacman. Usage: packages-test.sh [binary]
set -euo pipefail
bin="$(cd "$(dirname "${1:-./bxcachy}")" && pwd)/$(basename "${1:-./bxcachy}")"
fail() { echo "FAIL: $*" >&2; exit 1; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home/.local/share/applications"
# A pacman that reports a fixed set of installed packages.
cat > "$tmp/bin/pacman" <<'SH'
#!/usr/bin/env bash
[[ "$1 $2" == "-Qq " || "$1" == "-Qq" ]] && { printf '%s\n' git curl neovim; exit 0; }
exit 1
SH
chmod +x "$tmp/bin/pacman"
run() { env -i HOME="$tmp/home" PATH="$tmp/bin:$PATH" "$@"; }
rc() { set +e; "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
j() { run "$bin" "$@" --json; }

# installed detection
[[ "$(run "$bin" package-status git)" == 'git: installed' ]] || fail 'git installed'
[[ "$(rc run "$bin" package-status git)" == 0 ]] || fail 'installed exits 0'
[[ "$(rc run "$bin" package-status lazygit)" == 1 ]] || fail 'missing exits 1'
[[ "$(rc run "$bin" package-status nope-app)" == 3 ]] || fail 'unknown id exits 3'
[[ "$(rc run "$bin" package-status 'bad;id')" == 2 ]] || fail 'bad id exits 2'
[[ "$(j package-status git | jq -r '.data.installed')" == true ]] || fail 'status json'
# a web app is installed when its launcher exists
[[ "$(rc run "$bin" package-status boxlang-docs)" == 1 ]] || fail 'web app missing'
touch "$tmp/home/.local/share/applications/bxcachy-boxlang-docs.desktop"
[[ "$(rc run "$bin" package-status boxlang-docs)" == 0 ]] || fail 'web app launcher counts as installed'

# package-source reads the catalog
[[ "$(j package-source vscode | jq -r '.data.source')" == aur ]] || fail 'vscode source aur'
[[ "$(j package-source git | jq -r '.data.targets[0]')" == git ]] || fail 'git target'
[[ "$(rc run "$bin" package-source nope-app)" == 3 ]] || fail 'source unknown id'

# plan: installed apps are skipped, profile uses the profile tier
out="$(j plan --profile=core)"
[[ "$(jq -r '[.data.would_install[].id]|sort|join(",")' <<<"$out")" == jq,unzip ]] || fail 'core plan minus installed git, curl'
[[ "$(jq -r '[.data.skipped[]|select(.reason=="installed").id]|sort|join(",")' <<<"$out")" == curl,git ]] || fail 'installed skipped'
[[ "$(jq -r '.data.selection.mode' <<<"$out")" == profile ]] || fail 'selection mode'
out="$(j plan --profile=terminal --optional)"
jq -e '[.data.would_install[].id]|index("eza")' <<<"$out" >/dev/null || fail '--optional adds eza to terminal'
out="$(j plan --profile=terminal)"
jq -e '[.data.would_install[].id]|index("eza")|not' <<<"$out" >/dev/null || fail 'eza is optional in terminal'

# shells
out="$(env -i HOME="$tmp/home" PATH="$tmp/bin:$PATH" XDG_CURRENT_DESKTOP=KDE "$bin" plan --json)"
[[ "$(jq -r '.data.selection.shell' <<<"$out")" == plasma ]] || fail 'KDE detected as plasma'
out="$(j plan --shell=plasma)"
jq -e '[.data.skipped[]|select(.reason=="wrong_shell").id]|index("walker")' <<<"$out" >/dev/null || fail 'walker is wrong_shell on plasma'
out="$(j plan --shell=hyprland --optional)"
jq -e '[.data.skipped[]|select(.reason=="wrong_shell").id]|index("walker")|not' <<<"$out" >/dev/null || fail 'walker stays on hyprland'
out="$(j plan --shell=plasma)"
jq -e '[.data.skipped[]|select(.reason=="optional").id]|index("walker")|not' <<<"$out" >/dev/null || fail 'walker is not reported optional on plasma'
[[ "$(rc run "$bin" plan --shell=gnome)" == 2 ]] || fail 'unknown shell exits 2'

# named apps
out="$(j plan hyprsunset --shell=plasma)"
[[ "$(jq -r '.data.would_install[0].id' <<<"$out")" == hyprsunset ]] || fail 'named app ignores shell'
[[ "$(rc run "$bin" plan codex-cli)" == 3 ]] || fail 'named unresolved app exits 3'
[[ "$(rc run "$bin" plan nope-app)" == 2 ]] || fail 'unknown app exits 2'
[[ "$(rc run "$bin" plan neovim --profile=core)" == 2 ]] || fail 'ids with --profile exit 2'
[[ "$(rc run "$bin" plan --profile)" == 2 ]] || fail '--profile needs a value'

# web apps pull in brave
out="$(j plan gmail)"
[[ "$(jq -r '[.data.would_install[].id]|join(",")' <<<"$out")" == brave,gmail ]] || fail 'plan gmail includes brave first'

# npm apps count as installed when their command is in an nvm Node version
[[ "$(rc run "$bin" package-status pi-agent)" == 1 ]] || fail 'pi-agent missing without nvm'
mkdir -p "$tmp/home/.nvm/versions/node/v22.1.0/bin"; touch "$tmp/home/.nvm/versions/node/v22.1.0/bin/pi"
[[ "$(rc run "$bin" package-status pi-agent)" == 0 ]] || fail 'pi-agent installed when pi exists under nvm'

# lists
[[ "$(j profile-list | jq '.data|length')" -ge 12 ]] || fail 'profile-list'
[[ "$(j profile-list | jq -r '.data[]|select(.id=="core")|.default')" == 4 ]] || fail 'core has 4 default apps'
[[ "$(j web-list | jq '[.data[]|select(.kind!="web")]|length')" == 0 ]] || fail 'web-list only web'
[[ "$(j optional-list | jq '[.data[]|select(.tier!="optional")]|length')" == 0 ]] || fail 'optional-list only optional'
echo 'packages tests passed'

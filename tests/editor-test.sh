#!/usr/bin/env bash
# `bxrig editor lazyvim|boxlang|status|refresh`: the BxRig layer on the LazyVim starter, with fake git, pacman and sudo. Usage: editor-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/state"; export LOG="$tmp/log"; : > "$LOG"
# a fake starter: lazyvim.json with the starter's own keys, an options.lua of comments, an example plugin file
cat > "$tmp/bin/git" <<'FAKE'
#!/usr/bin/env bash
echo "git $*" >> "$LOG"
if [[ "$1" == clone ]]; then
  mkdir -p "$3/.git" "$3/lua/config" "$3/lua/plugins"
  echo 'require("config.lazy")' > "$3/init.lua"
  printf -- '-- Options are automatically loaded before lazy.nvim startup\n' > "$3/lua/config/options.lua"
  echo '{"extras":["lazyvim.plugins.extras.lang.json"],"install_version":8,"version":8}' > "$3/lazyvim.json"
  echo 'return {}' > "$3/lua/plugins/example.lua"
fi
FAKE
for t in pacman sudo; do printf '#!/usr/bin/env bash\necho "%s $*" >> "$LOG"\nif [[ "%s" == pacman && "$1" == -Q ]]; then exit 1; fi\n' "$t" "$t" > "$tmp/bin/$t"; done
chmod +x "$tmp/bin"/*
run() { env HOME="$tmp/home" BXRIG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
nv="$tmp/home/.config/nvim"; cfg="$tmp/home/.config"

[[ "$(code "$binary" editor lazyvim)" == 2 ]] || fail 'lazyvim without --yes exits 2'
[[ ! -e "$nv" ]] || fail 'the plan cloned'
run "$binary" editor lazyvim --yes --json | jq -e '.ok and (.data.layer | length == 6) and (.data.layer_result.failed | length == 0)' >/dev/null || fail 'lazyvim --yes'
for f in lua/config/bxrig.lua lua/plugins/bxrig.lua lua/plugins/boxlang.lua lua/plugins/bxrig-themes.lua lua/plugins/bxrig-theme-reload.lua plugin/after/bxrig-transparency.lua; do [[ -s "$nv/$f" ]] || fail "missing layer file $f"; done
[[ ! -e "$nv/.git" && -f "$nv/lua/plugins/example.lua" ]] || fail 'the starter is intact and its .git is gone'
grep -q 'ortus-boxlang/vim-boxlang' "$nv/lua/plugins/boxlang.lua" || fail 'the BoxLang plugin spec'
grep -q 'require("config.bxrig")' "$nv/lua/config/options.lua" && grep -q 'automatically loaded' "$nv/lua/config/options.lua" || fail 'options.lua keeps the starter text and loads the layer'
[[ "$(grep -c 'config.bxrig' "$nv/lua/config/options.lua")" == 1 ]] || fail 'the hook is added once'
jq -e '.extras | (index("lazyvim.plugins.extras.editor.neo-tree") != null) and (index("lazyvim.plugins.extras.lang.json") != null)' "$nv/lazyvim.json" >/dev/null || fail 'neo-tree added, the starter extras kept'
jq -e '.install_version == 8' "$nv/lazyvim.json" >/dev/null || fail 'the starter keys are kept'
[[ -L "$nv/lua/plugins/theme.lua" ]] && [[ "$(readlink "$nv/lua/plugins/theme.lua")" == "$tmp/state/bxrig/current/theme/neovim.lua" ]] && [[ -s "$nv/lua/plugins/theme.lua" ]] || fail 'theme.lua links to the current theme file, which exists'
grep -q 'catppuccin-frappe' "$nv/lua/plugins/theme.lua" || fail 'the default theme is bxrig (catppuccin frappe)'
[[ "$(ls "$cfg/bxrig/nvim-themes" | wc -l)" == 15 ]] || fail "every theme's neovim.lua is synced ($(ls "$cfg/bxrig/nvim-themes" | wc -l))"

# a theme change rewrites the file the link points at
run "$binary" theme set tokyo-night >/dev/null; grep -q 'tokyonight-night' "$nv/lua/plugins/theme.lua" || fail 'theme set reaches nvim through the link'

# status, refresh keeps your edits, --force restores them with a backup
run "$binary" editor status --json | jq -e '(.data.files | map(select(.state == "clean")) | length == 6) and .data.theme_link == "link"' >/dev/null || fail 'status clean'
echo '-- mine' >> "$nv/lua/plugins/bxrig.lua"
run "$binary" editor status --json | jq -e '.data.files | map(select(.file == "lua/plugins/bxrig.lua" and .state == "drifted")) | length == 1' >/dev/null || fail 'status sees the edit'
[[ "$(code "$binary" editor refresh)" == 2 ]] || fail 'refresh without --yes exits 2'
run "$binary" editor refresh --yes >/dev/null; grep -q '^-- mine' "$nv/lua/plugins/bxrig.lua" || fail 'refresh kept the edited file'
run "$binary" editor refresh --yes --force >/dev/null; ! grep -q '^-- mine' "$nv/lua/plugins/bxrig.lua" || fail 'refresh --force restored it'

# an existing config is never touched by lazyvim; boxlang adds one file to it
[[ "$(code "$binary" editor lazyvim --yes)" == 4 ]] || fail 'an existing nvim config exits 4'
rm "$nv/lua/plugins/boxlang.lua"
[[ "$(code "$binary" editor boxlang)" == 2 ]] || fail 'boxlang without --yes exits 2'
run "$binary" editor boxlang --yes >/dev/null; grep -q 'vim-boxlang' "$nv/lua/plugins/boxlang.lua" || fail 'boxlang --yes'
run "$binary" editor boxlang --yes | grep -q 'Already in place' || fail 'boxlang is idempotent'
echo 'return { { "my/own" } }' > "$nv/lua/plugins/boxlang.lua"
[[ "$(code "$binary" editor boxlang --yes)" == 4 ]] || fail 'a boxlang.lua you wrote is left alone'
[[ "$(cat "$nv/lua/plugins/boxlang.lua")" == 'return { { "my/own" } }' ]] || fail 'the file was changed'
rm -rf "$nv"; [[ "$(code "$binary" editor boxlang --yes)" == 4 ]] || fail 'boxlang without a LazyVim config exits 4'
[[ "$(code "$binary" editor refresh --yes)" == 4 ]] || fail 'refresh without a config exits 4'
echo "editor-test: ok"

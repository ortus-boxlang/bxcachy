# BxRig shell setup for fish (managed by `bxrig setup shell`; your own settings belong in ~/.config/fish/config.fish).
# Fish has autosuggestions, syntax highlighting and completions built in.
if status is-interactive
    command -q fzf; and fzf --fish | source
    command -q zoxide; and zoxide init fish | source
    # Starship prompt (the same prompt in every shell; config: ~/.config/starship.toml)
    command -q starship; and starship init fish | source
end
# API keys: per-command loaders written by `bxrig secrets` (no values in this file)
set -l bxc_cfg $HOME/.config; set -q XDG_CONFIG_HOME; and set bxc_cfg $XDG_CONFIG_HOME
test -r "$bxc_cfg/bxrig/secrets.fish"; and source "$bxc_cfg/bxrig/secrets.fish"
test -r "$bxc_cfg/bxrig/java.fish"; and source "$bxc_cfg/bxrig/java.fish"
test -r "$bxc_cfg/bxrig/sdk.fish"; and source "$bxc_cfg/bxrig/sdk.fish"

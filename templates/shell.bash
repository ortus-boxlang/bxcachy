# BxRig shell setup for bash (managed by `bxrig setup shell`; your own settings belong in ~/.bashrc).
HISTSIZE=50000
HISTFILESIZE=50000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend checkwinsize autocd 2>/dev/null

[[ -r /usr/share/bash-completion/bash_completion ]] && source /usr/share/bash-completion/bash_completion
command -v fzf >/dev/null && eval "$(fzf --bash)"
command -v zoxide >/dev/null && eval "$(zoxide init bash)"
# Starship prompt (the same prompt in every shell; config: ~/.config/starship.toml)
command -v starship >/dev/null && eval "$(starship init bash)"
# API keys: per-command loaders written by `bxrig secrets` (no values in this file)
[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/bxrig/secrets.sh" ] && . "${XDG_CONFIG_HOME:-$HOME/.config}/bxrig/secrets.sh"
# Java: the default home chosen with `bxrig java default` (no file, no change)
[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/bxrig/java.sh" ] && . "${XDG_CONFIG_HOME:-$HOME/.config}/bxrig/java.sh"
# Maven and Gradle from SDKMAN, set by `bxrig sdk` (no file, no change)
[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/bxrig/sdk.sh" ] && . "${XDG_CONFIG_HOME:-$HOME/.config}/bxrig/sdk.sh"

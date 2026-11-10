# BxCachy shell setup for bash (managed by `bxcachy setup shell`; your own settings belong in ~/.bashrc).
HISTSIZE=50000
HISTFILESIZE=50000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend checkwinsize autocd 2>/dev/null

[[ -r /usr/share/bash-completion/bash_completion ]] && source /usr/share/bash-completion/bash_completion
command -v fzf >/dev/null && eval "$(fzf --bash)"
command -v zoxide >/dev/null && eval "$(zoxide init bash)"
# Starship prompt (the same prompt in every shell; config: ~/.config/starship.toml)
command -v starship >/dev/null && eval "$(starship init bash)"

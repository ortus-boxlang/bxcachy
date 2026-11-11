# BxCachy shell setup for zsh (managed by `bxcachy setup shell`; your own settings belong in ~/.zshrc).
# Plugins come from pacman (zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions), not from a plugin manager.
HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS SHARE_HISTORY AUTO_CD INTERACTIVE_COMMENTS

autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

[[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
command -v fzf >/dev/null && source <(fzf --zsh)
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
# syntax highlighting must be loaded after everything that binds keys or widgets
[[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# Starship prompt (the same prompt in every shell; config: ~/.config/starship.toml)
command -v starship >/dev/null && eval "$(starship init zsh)"
# API keys: per-command loaders written by `bxcachy secrets` (no values in this file)
[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/bxcachy/secrets.sh" ] && . "${XDG_CONFIG_HOME:-$HOME/.config}/bxcachy/secrets.sh"

# BxCachy shell setup for fish (managed by `bxcachy setup shell`; your own settings belong in ~/.config/fish/config.fish).
# Fish has autosuggestions, syntax highlighting and completions built in.
if status is-interactive
    command -q fzf; and fzf --fish | source
    command -q zoxide; and zoxide init fish | source
    # Starship prompt (the same prompt in every shell; config: ~/.config/starship.toml)
    command -q starship; and starship init fish | source
end

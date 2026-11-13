---
title: The setup wizard
order: 1
summary: One guided form for every choice. Re-run it any time.
---

# The setup wizard

`bxcachy init` opens a full-screen form with these pages: **Desktop**, **Look**, **Input**, **Developer**, **Toolchains**, **Containers**, **Apps**, **AI**, **Extras** and **Import**, then a review screen that lists exactly the commands it will run. Nothing runs until you confirm.

## Run it again

On a machine that is already set up the wizard starts from your saved answers plus what it finds on the system, and marks installed options with `✓ installed`.

| Command | Starts from |
|---|---|
| `bxcachy init` | your saved answers and what the system has (tune) |
| `bxcachy init --rerun` | your saved answers only |
| `bxcachy init --fresh` | the defaults |
| `bxcachy init --from FILE` | an answers file from another machine |

Nothing the machine already has is ever removed. `bxcachy status` shows the same scan without opening the wizard.

## Without a terminal

```bash
bxcachy init --answers answers.json --yes     # apply an answers file
bxcachy init --defaults --yes                  # the wizard's default answers
bxcachy init --dry-run                         # show the plan only
bxcachy init --export answers.json             # save your answers for another machine
```

Answers are saved in `~/.config/bxcachy/answers.json` (mode 600). They never contain secrets.

## Defaults worth knowing

| Question | Default |
|---|---|
| Desktop | Hyprland + Noctalia |
| Workspaces | 4 |
| Shell | zsh with the Starship prompt (Catppuccin Powerline) |
| Terminal | Ghostty |
| File manager | Strata |
| Toolchains | Java and Rust |
| Containers | Podman (with `docker` commands mapped to it) |
| Dictation | Superwhisper (Voxtype is the alternative) |
| Updates | stable channel, daily notification |

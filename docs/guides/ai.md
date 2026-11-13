---
title: AI agents and skills
order: 5
summary: Coding agents, API keys in your keyring, local models, and skills for every agent.
---

# AI agents and skills

## Agents

BxCachy installs and launches coding agents (Claude Code, Codex, Gemini CLI, OpenCode) and orchestrators.

```bash
bxcachy ai list
bxcachy ai default claude-code --yes
bxcachy ai launch                   # the default agent, with its keys loaded
bxcachy ai shell                    # a pull-down terminal (Super+`)
bxcachy ai session start            # a persistent tmux session
```

## API keys

Keys are stored in your desktop keyring (BxCachy installs one if you have none), never in files or shell history.

```bash
bxcachy secrets set ANTHROPIC_API_KEY     # typed hidden
bxcachy secrets list
bxcachy secrets run ANTHROPIC_API_KEY -- some-command
```

Each key is marked as an AI key or another kind, and agents declare which providers they accept (OpenCode can use several). Exporting keys globally is opt-in. Move keys between machines with `bxcachy secrets export` (encrypted with age).

## Local models

`bxcachy ai models list|ps|pull MODEL|rm|enable` drives Ollama. `bxcachy gpu doctor` shows what your GPU needs (`ollama-cuda` or `ollama-rocm`).

## Skills for every agent

**Skills** are small `SKILL.md` files that teach an agent how to do one thing well. BxCachy stores them once in `~/.agents/skills` and links each one into the skills folder of every agent you have (Claude Code, Codex, Gemini CLI, OpenCode). A folder of your own with the same name is never replaced.

```bash
bxcachy skills install bxcachy boxlang matchbox --yes
bxcachy skills status
bxcachy skills search matchbox            # the skills.boxlang.io hub
bxcachy skills install ortus-boxlang/skills/boxlang-developer~language-fundamentals --yes
bxcachy skills update --yes
```

| Name | What it is |
|---|---|
| `bxcachy` | Five skills about BxCachy itself, shipped inside the program |
| `boxlang` | BoxLang language fundamentals, from the hub |
| `matchbox` | The MatchBox runtime, from the hub |

The hub ([skills.boxlang.io](https://skills.boxlang.io)) audits every skill. A skill that failed its audit is refused. Skills are optional in the wizard (AI page).

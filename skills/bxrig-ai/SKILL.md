---
name: bxrig-ai
description: "Use this skill when working with AI tools through BxRig: coding agents, the default agent, API keys and secrets, the pull-down AI shell, persistent tmux agent sessions, local models with Ollama, or installing agent skills with bxrig skills."
---

# BxRig: AI

- Agents: `bxrig ai list`, `ai default ID`, `ai launch [ID]` (with its keys loaded), `ai shell` (pull-down terminal, `Super+``), `ai session start|list|attach|stop`.
- Keys: `bxrig secrets set KEY` (typed hidden, stored in the keyring), `secrets list|unset|run KEYS -- cmd`. `secrets` marks each key as an AI key or other. Never put keys in files, shell history or answers.json. Global export is opt-in: `secrets global on KEY`.
- Local models: `bxrig ai models list|ps|pull MODEL|rm|enable`. GPU help: `bxrig gpu doctor`.
- Skills for agents: `bxrig skills list|search TEXT|show REF|install REF...|installed|update|remove NAME|status`. They are stored once in `~/.agents/skills` and linked into each agent's skills folder. The hub is https://skills.boxlang.io (an API, audited skills; a skill that failed its audit cannot be installed).

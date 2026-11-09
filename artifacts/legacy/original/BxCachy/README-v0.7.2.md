# BxCachy v0.7.2 - AI workstation hardening

This release extends the v0.7.1 AI workstation without changing KDE, Noctalia, or your existing Super+Space runner.

## Commands

- `./bin/bxcachy ai dropdown`: open/toggle AI special workspace (`Super+Alt+A` after explicitly enabling the generated shortcut).
- `./bin/bxcachy ai sessions list|attach <agent>|stop <agent>`: tmux session management.
- `./bin/bxcachy ai config show|path|reset`: inspect and reset AI settings.
- `./bin/bxcachy ai service status|start|stop|enable`: Ollama system service.
- `./bin/bxcachy ai lmstudio list|loaded|load <model>|unload <model>|server-start|server-stop`: LM Studio CLI, requires official LM Studio application.
- `./bin/bxcachy ai models list|running|pull <model>|remove <model>`: Ollama model commands.
- `./bin/bxcachy ai install <codex|opencode|gemini|ollama> --dry-run`: preview supported automated installers.
- `./bin/bxcachy ai install claude --dry-run` and `... lmstudio --dry-run`: official installation instructions; **not** automated.

## Limitations

- Claude Code and LM Studio installation remains manual pending verified, secure upstream distribution flows.
- AI dropdown and generated Hyprland window rules require real-session testing. The generated rules use legacy `windowrulev2` syntax, which may differ in newer Hyprland versions.
- No changes to the user's Hyprland configuration are applied automatically.
- npm global installs may require a user-owned npm prefix; avoid `sudo npm`.
- Persistent tmux sessions depend on tmux and an installed agent binary.
- No external downloads are executed by the test suite.

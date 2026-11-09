# BxCachy runner interface (v0.9.1)

The launcher provider and management-menu provider are independent. `system` preserves the existing Super+Space desktop runner.

```sh
./bin/bxcachy runner list
./bin/bxcachy runner set vicinae
./bin/bxcachy runner set hyprrunner
./bin/bxcachy runner set rofi
./bin/bxcachy runner menu-set rofi
./bin/bxcachy runner menu-set walker
./bin/bxcachy runner doctor
```

Launcher interface: `resolve(provider, config)` produces an executable argv array; `launch` checks availability. Menu interface: `menu-select --prompt` accepts newline-delimited labels with optional Rofi icon metadata and returns a selected numeric index. Rofi and Walker provide menu adapters. Vicinae and Hyprrunner are launcher-only until their exact installed CLI and dmenu protocols are validated on CachyOS; they do not silently replace the management menu. No shortcuts are changed.

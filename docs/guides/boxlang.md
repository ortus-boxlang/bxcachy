---
title: BoxLang and MatchBox
order: 6
summary: The BoxLang developer ecosystem on your machine.
---

# BoxLang and MatchBox

The installer puts in Java 21, **bvm** (BoxLang Version Manager), **mvm** (MatchBox Version Manager), BoxLang and MatchBox. `bxrig boxlang` sits on top of them.

```bash
bxrig boxlang status
bxrig boxlang use latest              # bvm: install if missing, then use
bxrig boxlang use snapshot
bxrig boxlang matchbox use latest     # mvm
bxrig boxlang modules list            # the live ForgeBox list
bxrig boxlang modules search ai
bxrig boxlang modules install bx-ai bx-sites
bxrig boxlang modules update
bxrig boxlang vscode                  # the BoxLang extension and developer pack
bxrig boxlang links                   # docs and sites
bxrig boxlang welcome                 # a getting-started page
```

Modules come from [ForgeBox](https://forgebox.io) and install with `bx-module`. VS Code is a default app; the wizard offers to add the BoxLang extension (`ortus-solutions.vscode-boxlang`) and the developer pack.

## Compile to a native binary

```bash
matchbox script.bxs
```

[MatchBox](https://matchbox.boxlang.io) compiles BoxLang to bytecode on a Rust runtime and can build standalone native binaries. BxRig itself is built this way.

## Links

[Try BoxLang](https://try.boxlang.io) · [Docs](https://boxlang.ortusbooks.com) · [BoxLang AI](https://ai.boxlang.io) · [BoxLang Agents](https://bxagents.ai) · [BoxLang Sites](https://bxsites.io) · [ForgeBox](https://forgebox.io) · [Skills](https://skills.boxlang.io)

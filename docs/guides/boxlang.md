---
title: BoxLang and MatchBox
order: 6
summary: The BoxLang developer ecosystem on your machine.
---

# BoxLang and MatchBox

The installer puts in Java 21, **bvm** (BoxLang Version Manager), **mvm** (MatchBox Version Manager), BoxLang and MatchBox. `bxcachy boxlang` sits on top of them.

```bash
bxcachy boxlang status
bxcachy boxlang use latest              # bvm: install if missing, then use
bxcachy boxlang use snapshot
bxcachy boxlang matchbox use latest     # mvm
bxcachy boxlang modules list            # the live ForgeBox list
bxcachy boxlang modules search ai
bxcachy boxlang modules install bx-ai bx-sites
bxcachy boxlang modules update
bxcachy boxlang vscode                  # the BoxLang extension and developer pack
bxcachy boxlang links                   # docs and sites
bxcachy boxlang welcome                 # a getting-started page
```

Modules come from [ForgeBox](https://forgebox.io) and install with `bx-module`. VS Code is a default app; the wizard offers to add the BoxLang extension (`ortus-solutions.vscode-boxlang`) and the developer pack.

## Compile to a native binary

```bash
matchbox script.bxs
```

[MatchBox](https://matchbox.boxlang.io) compiles BoxLang to bytecode on a Rust runtime and can build standalone native binaries. BxCachy itself is built this way.

## Links

[Try BoxLang](https://try.boxlang.io) · [Docs](https://boxlang.ortusbooks.com) · [BoxLang AI](https://ai.boxlang.io) · [BoxLang Agents](https://bxagents.ai) · [BoxLang Sites](https://bxsites.io) · [ForgeBox](https://forgebox.io) · [Skills](https://skills.boxlang.io)

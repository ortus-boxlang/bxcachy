---
title: Move to another machine
order: 8
summary: Export your settings, answers and keys, and import them elsewhere.
---

# Move to another machine

```bash
bxcachy settings export my-settings.tar.gz
bxcachy settings import my-settings.tar.gz --yes
```

Export bundles `~/.config/bxcachy` (answers, shortcuts, runner and update settings) **without secrets, backups or state**. Import backs up each existing file as `NAME.bak-STAMP` first and refuses archives with paths outside `bxcachy/`.

Keys travel separately and encrypted: `bxcachy secrets export` and `bxcachy secrets import`.

To set up a new machine without touching the old one, export only the wizard answers: `bxcachy init --export answers.json`, then on the new machine `bxcachy init --from answers.json`, or run unattended with `--answers answers.json --yes`.

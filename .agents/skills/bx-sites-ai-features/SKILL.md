---
name: bx-sites-ai-features
metadata:
  version: "1.0"
description: Use bx-sites' (ortus-boxlang/bx-sites) AI-facing features - agent instruction files (AGENTS.md/CLAUDE.md/.cursorrules via bxSites new --agents and agents:sync), the llms.txt and per-page Markdown source every build publishes, bxsites.yaml's mcp:true (full-text site/mcp-index.json + mcp-manifest.json + per-tree mcp-nav.json for bxSites Cloud's read-only MCP server), and installing the bx-sites-skills pack (npx skills add, coldbox ai skills install, or bxSites skills:install). Use this whenever a user wants AI coding assistants to know how to author a bx-sites project, wants their published site's content reachable by LLMs or MCP-aware agents, or wants to install/update the skill pack itself in a project.
---

# BxSites AI Features

Four independent, AI-facing features. Two help an AI coding assistant
*author* a bx-sites project: short always-present **instruction files**
(`AGENTS.md` and friends) and the on-demand **skill pack** (this
repository). Two expose a *published site's own content* to AI agents:
**`llms.txt` + published Markdown source** (always on) and the **MCP index**
(`mcp: true`).

## Agent instruction files (AGENTS.md, CLAUDE.md, .cursorrules)

```bash
bxSites new my-docs --agents=agents,claude,cursor   # pick the files (default: agents only)
bxSites new my-docs --agents=none                   # or --no-agents: skip them
bxSites agents:sync [--agents=agents,claude,cursor] # retrofit/refresh an existing project
```

`new` writes `AGENTS.md` by default; `claude` adds `CLAUDE.md` and `cursor`
adds `.cursorrules`. Each holds the same short content-authoring cheat sheet
(frontmatter keys, content-block directives, reserved folders, the
`page:new` -> `serve` -> `lint` -> `build` workflow), generated from the
project's real theme and source folder, inside a marked block:

```text
<!-- bxsites:agents:start -->
...generated cheat sheet...
<!-- bxsites:agents:end -->
```

- Only the text between the markers is ever replaced; anything written above
  or below survives every `agents:sync` (run it after a bx-sites upgrade).
- A target file that exists **without** the markers is skipped and reported,
  never overwritten - delete the markers on purpose to opt a file out.
- A missing target file is created; `.markdownlint.json` is always
  (re)written, by both `new` and `agents:sync`, even with `--agents=none`.
- An unknown `--agents` target throws `BxSites.UnknownAgentTarget`.

**Instruction file vs skill pack:** the instruction file is a short,
always-loaded cheat sheet covering what most content edits need; the skills
below are 16 detailed guides an assistant loads on demand for a specific
task (theming, deployment, i18n, ...). Most projects benefit from both. Not
to be confused with the `AGENTS.md` in the bx-sites repo itself, which is
about working on bx-sites' own source.

## `llms.txt` and published Markdown source

No config needed. Every build:

- writes `site/llms.txt` - a Markdown index listing every non-hidden page
  (absolute URLs when `baseURL` is a full URL, else base-path relative).
  Each page's title links to its published raw `.md` source, with a separate
  `[HTML]` link to the rendered page;
- publishes each page's original `.md` next to its HTML
  (`site/guides/deployment.md` beside `site/guides/deployment/index.html`),
  with a "Download Markdown" link on the page.

An LLM can fetch clean Markdown directly instead of scraping rendered HTML.
This is separate from `mcp: true`, which adds a structured index for MCP
clients.

## MCP server (`mcp: true`)

```yaml title="bxsites.yaml"
mcp: true
```

Every `build` then writes three files alongside the rendered pages, which
[bxSites Cloud](https://bxsites.io/cloud) reads to expose a public,
read-only [MCP](https://modelcontextprotocol.io/) server for the *published*
site (the same idea as GitBook's "MCP servers for published docs") - so
Claude, ChatGPT, or any other MCP-aware client can search/browse/retrieve
content directly instead of scraping rendered HTML. Building the files is
free with `bxSites build` alone; actually serving them over the network as
a live MCP server needs a paid bxSites Cloud plan. `false` (default) skips
the whole step - no extra cost, nothing written.

**Independent of `search`/`searchProvider`** - unrelated switches. `mcp`
never touches the visitor-facing search box, and turning `search` off never
disables `mcp-index.json`. This is also why it can't reuse
`search-index.json`: that file only exists for the `"local"` provider and is
deliberately truncated (400 chars/entry, shipped to every visitor's
browser); `mcp-index.json` is fetched server-side by bxSites Cloud and keeps
the **complete**, untruncated page body.

### The three files

- **`site/mcp-index.json`** - one entry per non-hidden page/post: `title`,
  `url`, `tags`, `headings` (every `h1`-`h6`, in order), `body` (complete
  plain text, HTML stripped, never truncated), `type` (`"page"`/`"post"`),
  `categories` (post only, `[]` for a page), `updatedAt`. For a blog post
  `updatedAt` is its raw frontmatter `date`; for a docs page it is the
  frontmatter `date` if set, else the source file's last-modified time as
  ISO-8601, else `""`.
- **`site/mcp-manifest.json`** - one per build (site root only): every tree
  that got its own index/nav (`path`, `label`, `version`, `locale`,
  `default`), so bxSites Cloud's MCP server can offer version/locale-aware
  tools without guessing bx-sites' own directory conventions.
- **`site/mcp-nav.json`** - one per tree (main, `/next/`, each
  `/versions/<name>/`, each locale sub-tree): that tree's own nav, the exact
  same nested `{ title, url, order, icon, children }` shape the theme's
  sidebar renders from. A group heading with no `index.md` of its own has an
  empty `url`.

`mcp-index.json` and `mcp-nav.json` are written once per rendered tree;
`mcp-manifest.json` once per build, at the site root - same "once per tree
vs. once per build" split `search-index.json` and the version/locale system
already use (see `bx-sites-blog-versioning-i18n`).

## Installing this skill pack in a project

[`ortus-boxlang/bx-sites-skills`](https://github.com/ortus-boxlang/bx-sites-skills)
(this repository) is the official skill pack - every skill is a single
self-contained `SKILL.md`, so any install path below installs it correctly.
Works with any assistant supporting the Agent Skills format (Claude Code,
Cursor, Codex, and others).

### `npx skills add` (any project, needs only Node.js)

```bash
npx skills add ortus-boxlang/bx-sites-skills           # whole pack
npx -y skills add ortus-boxlang/bx-sites-skills -y     # non-interactive (CI/scripts)
npx skills add ortus-boxlang/bx-sites-skills/skills/bx-sites-deployment   # one skill
```

### `coldbox ai skills install` (ColdBox CLI)

```bash
coldbox ai skills install ortus-boxlang/bx-sites-skills/bx-sites-deployment
```

See the [BoxLang Skills Directory](https://skills.boxlang.io/) for the
catalog this pulls from.

### `bxSites skills:install` (bx-sites' own wrapper)

A thin wrapper that installs straight into the current project (or
`--projectRoot`, which must exist) - handy right after scaffolding, so the
assistant knows bx-sites from the very first prompt. It runs
`npx -y skills add ortus-boxlang/bx-sites-skills[/skills/<name>] -y` in the
project root: non-interactive, installing into every AI assistant it
detects there:

```bash
bxSites skills install
bxSites skills:install --skill=bx-sites-deployment   # one skill
```

Requires Node.js/`npx` on `PATH`, the same requirement `npx skills add` has
on its own. A failure (no `npx`, network error, ...) throws
`BxSites.SkillsInstallFailed` and exits `1`; on success it tells you to
restart or reload any AI assistant open on the project to pick up the new
skills.

### Verifying an install

Look for a new `SKILL.md` under the assistant's own skills directory (e.g.
`.claude/skills/bx-sites-getting-started/SKILL.md` for Claude Code), or just
ask the assistant something a skill covers and check the answer matches
this pack's own documentation.

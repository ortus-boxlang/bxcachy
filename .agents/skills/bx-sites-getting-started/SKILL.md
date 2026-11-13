---
name: bx-sites-getting-started
metadata:
  version: "1.0"
description: Install bx-sites (ortus-boxlang/bx-sites) and scaffold a new site, or bring an existing GitBook/mkdocs/Notion/markdown-zip project into one - project layout, content source resolution, page frontmatter, linking between pages, and the basic build/serve/clean loop. Use this whenever a user wants to start a new bx-sites project, add/move a plain docs page, or migrate an existing docs project in. For advanced Markdown/content-block syntax, use bx-sites-content-blocks/bx-sites-markdown; for bxsites.yaml keys, themes, or deployment, use bx-sites-configuration/bx-sites-themes/bx-sites-deployment; for the blog/versions/i18n, use bx-sites-blog-versioning-i18n.
---

# BxSites Getting Started

BxSites (`ortus-boxlang/bx-sites`) is an AI-first static site generator in
the spirit of mkdocs/GitBook: point it at a `docs/` (or `src/`) folder of
Markdown and it builds a themed, searchable static site - docs, blogs,
marketing sites or knowledge bases. Every build is AI-ready (`llms.txt`, an
optional MCP manifest), and a site can be hosted anywhere or published to
bxSites Cloud. It runs on BoxLang.

Every command runs as `bxSites <verb> [options]` (or
`boxlang bxSites <verb> [options]` where the `PATH` shim isn't installed -
e.g. a CI runner). Every verb accepts `--projectRoot=<path>` or a bare
positional path as the project root (`bxSites build ../my-docs`), so **a
verb's own primary argument always uses `--flag=value`, never a bare
positional value** - it would be read as the project root. Exceptions:
`new my-docs` takes the target directory as a bare path; `serve` also takes
`--port 9191 --host 127.0.0.1` space-separated; and any colon verb also
works as two words (`bxSites page new --path=...`).

## Prerequisites

BxSites needs BoxLang 1.18 or later (`box.json`'s `minimumVersion`) plus
`bx-markdown`, `bx-esapi`, `bx-yaml`, `bx-image`, `bx-ftp`, `bx-toml` (all
installed automatically as `box.json` dependencies; `doctor` only checks
`bx-toml`/`bx-ftp` when the project actually uses a TOML file or an
ftp/sftp deployment):

```bash
# Install BoxLang itself first, if not already present
curl -fsSL https://install.boxlang.io/ | bash
# or BVM (side-by-side version management):
curl -fsSL https://install-bvm.boxlang.io/ | bash && bvm install latest && bvm use latest

# Then install bx-sites
install-bx-module bx-sites   # OS binary installer
# or
box install bx-sites          # CommandBox
```

Either installer drops a `bxSites` script on `PATH`.

### Tab completion

The module ships completion scripts for bash, fish and PowerShell in its
`completions/` folder. They complete verbs (`page:new` or `page new`), flags and
fixed-value flags (`--theme=`, `--target=`, `--from=`).

- **bash**: automatic with `install-bx-module bx-sites` (it reads
  `boxlang.completions` from the module's `box.json`). Otherwise add
  `source <module folder>/completions/bxSites.bash` to `~/.bashrc`.
- **fish**: `cp <module folder>/completions/bxSites.fish ~/.config/fish/completions/`
- **PowerShell**: add `. <module folder>/completions/bxSites.ps1` to `$PROFILE`.

The scripts are generated from the verb table; contributors regenerate them
with `boxlang tools/generate-completions.bxs` (a spec fails when they are stale).

## Scaffold a new project

```bash
bxSites new my-docs [--name="My Project Docs"] [--theme=material] [--description=...] [--format=yaml|toml|json] [--source=docs|src] [--agents=agents,claude,cursor|none] [--no-agents]
cd my-docs
```

Creates:

```text
my-docs/
├── docs/
│   ├── assets/
│   └── index.md
├── bxsites.yaml
├── .markdownlint.json
└── AGENTS.md
```

`new` refuses to run if the target already has a
`bxsites.yaml`/`.yml`/`.toml`/`.json` (`BxSites.ProjectAlreadyExists`).

- `--theme` defaults to `bootstrap` - see the `bx-sites-themes` skill for
  all 10 built-in options.
- `--format` defaults to `yaml` (scaffolds `bxsites.yaml`, the
  default/preferred format); `toml` scaffolds `bxsites.toml`, `json`
  `bxsites.json`. All three are fully supported and equivalent - see the
  `bx-sites-configuration` skill for the full key reference.
- `--source` defaults to `docs`; `--source=src` scaffolds `src/` instead for
  a project that isn't really "docs" in spirit (a marketing site, a
  portfolio). `--docs`/`--site` are shortcuts for the two - use only one.
  The scaffolded config gets an explicit `source: docs` (or `src`), which
  every later verb honours (see "Project layout"); build output always goes
  to `site/`.
- `AGENTS.md` (a short content-authoring cheat sheet for AI assistants) and
  `.markdownlint.json` are written by default. `--agents=agents,claude,cursor`
  also picks `CLAUDE.md`/`.cursorrules`; `--agents=none` or `--no-agents`
  skips the instruction files (the lint config is always written). See
  `bx-sites-ai-features`.

## Bringing an existing project in

```bash
bxSites migrate --source=<path> [--from=gitbook|mkdocs|markdown-zip|notion] [--force]
```

Converts an existing project into the content folder (`docs/` by default):

- `--from=gitbook` (default) - needs a `SUMMARY.md`-rooted GitBook export.
  `{% block %}` syntax becomes its bx-sites equivalent (`::: name`
  directives - see `bx-sites-content-blocks`). Writes `nav.json`; assets go
  to `docs/assets/gitbook/`.
- `--from=mkdocs` - needs `mkdocs.yml`; most syntax carries over unchanged
  since mkdocs-material's own admonition/tabs/math conventions already
  *are* bx-sites' native syntax. Writes `bxsites.yaml` (and `nav.json` when
  `mkdocs.yml` has a `nav`); assets go to `docs/assets/mkdocs/`.
- `--from=markdown-zip` - a plain `.zip` of Markdown files, no proprietary
  format to translate. Writes no config and no `nav.json`; assets go to
  `docs/assets/imported/`.
- `--from=notion` - a Notion "Export as Markdown & CSV" archive (`.zip` or
  an extracted folder); strips Notion's id-suffixed filenames and turns
  the duplicated leading `# Heading` into real `title` frontmatter. Writes
  no config and no `nav.json`; assets go to `docs/assets/imported/`.

All four print a conversion summary and a list of anything that needs a
manual look - nothing is silently dropped, but existing files at the
destination are overwritten, so review before committing. When the content
folder already has files (or, for `--from=mkdocs`, `bxsites.yaml` exists),
`migrate` asks `[y/N]` first; `--force` skips the prompt, and a closed stdin
(CI, piped) exits `1` with a "pass --force" hint. A relative `--source`
resolves against the project root; `~/` means your home folder.

## Project layout

```text
my-docs/
├── bxsites.yaml            # site config (.toml/.json also supported)
├── deployments/*           # deploy targets, .yaml/.yml/.toml/.json (see bx-sites-deployment)
└── docs/                   # or src/, or wherever `source:` points - every .md file here is a page
    ├── .theme/              # optional project theme override, inside the content root (see bx-sites-themes)
    ├── index.md
    ├── functions.bxs       # magic functions, see bx-sites-variables-functions
    ├── nav.json            # optional explicit nav (alternative to bxsites.yaml's nav key)
    ├── 404.md               # optional custom 404 page
    ├── robots.txt           # optional hand-authored robots.txt (overrides generated one)
    ├── assets/              # images, downloads, icons - copied to site/assets/
    │   └── gallery/<name>/  # {name}-{N}.jpg|png|webp|gif, for ::: image-gallery name="..."
    ├── data/                # optional data files, reachable as {{ data.<file> }}
    ├── includes/            # reusable content fragments, spliced via ::: include
    ├── blog/                # see bx-sites-blog-versioning-i18n
    ├── versions/            # see bx-sites-blog-versioning-i18n
    └── i18n/                # see bx-sites-blog-versioning-i18n
```

Folder nesting under `docs/` becomes nav nesting automatically (override
with an explicit `nav` - see `bx-sites-configuration`). `assets/`, `blog/`,
`versions/`, `i18n/`, and `includes/` are reserved folder names with special
meaning - don't repurpose them for ordinary content. (`data/` is a
convention folder rather than a reserved one - see
`bx-sites-variables-functions`.)

**Content root resolution:** the config's `source` key wins when set -
`docs`, `src`, any custom folder name, or `.` for the whole repo. Only when
`source` is unset does bx-sites auto-detect `docs/` then `src/`; if it is
unset and neither exists, the verb fails with `BxSites.SourceNotConfigured`.
A project that isn't really "docs" in spirit (a marketing site, a
portfolio) can use `src/` with zero other changes.

**Not pages:** dot-prefixed folders/files (`.git`, `.claude`, ...), the
default excludes (`.git`, `.github`, `boxlang_modules`, `node_modules`,
`site`, `.theme`, `.themes`, the `bxsites.*` config files, `box.json`) and
anything in the config's `exclude:` list are never scanned as pages.

## Adding and scaffolding pages

```bash
bxSites page:new --path=guides/setup.md [--title=] [--description=] [--icon=] [--tags=] [--order=]
```

Scaffolds a single page at an arbitrary `docs/`-relative path with
frontmatter pre-filled. Every `.md` file under `docs/` becomes a page.

```bash
bxSites page:rename --from=guides/old.md --to=guides/new.md
```

Moves a page, rewrites every relative Markdown link across `docs/**` that
pointed at it, and stamps `redirect_from` on the moved page automatically
(see `bx-sites-blog-versioning-i18n` for redirects). Always prefer this
over hand-moving a file.

### Page frontmatter

```markdown
---
title: Deployment
order: 2
hidden: false
description: How to deploy a built BxSites site.
tags: [guides, deployment]
icon: 🚀
summary: Everything you need to publish a built site.
ogImage: assets/deployment-card.png
toc: true
redirect_from: [guides/old-deploy-guide]
---

# Deployment
Your content here.
```

- `title` - nav/page title (defaults to filename)
- `order` - sibling sort order in nav (lower first; omitted sorts last, alphabetically)
- `hidden: true` - excludes from nav and search, still built
- `description` - meta description / social card; when unset falls back to the page's own `summary`, then a 160-char plain-text excerpt of its content, then the site-wide `description`
- `tags` - array; renders as badges and feeds the site-wide `/tags/` index; boosts search relevance
- `icon` - emoji or a named icon (`rocket`, `lucide:rocket`, `phosphor-bold:rocket`, `tabler:rocket`, `custom:my-icon` from `docs/assets/icons/my-icon.svg`) - see `bx-sites-markdown`
- `summary` - a one-line lead-in rendered under the title (distinct from `description`, which is meta-only)
- `ogImage` - per-page social card image, overrides the site-wide one
- `toc: false` - hides the page's own "On this page" TOC even with 2+ headings
- `redirect_from` - array of old pretty-URL segments that should redirect here; `page:rename` stamps this automatically
- `layout` - renders this page through a named theme template instead of the theme's defaults (e.g. `layout: home` for a marketing homepage); a name with no matching file falls back to `page.bxm` instead of failing - see `bx-sites-themes`

It's a small hand-rolled parser, not full YAML: inline lists (`tags: [a, b]`),
block lists (`- item`), and `>`/`|` block scalars work; nested
objects/maps do not.

## Linking between pages

Link with a file-relative path to the target's `.md` source, exactly as if
browsing the repo on disk - `[Deployment](guides/deployment.md)`,
`[back](../getting-started.md#add-pages)`. BxSites rewrites it to the built
pretty-URL at build time, resolved against the *linking* page's own folder.
Absolute URLs, `mailto:`, and links already starting with `/` are left alone.

## Downloading a page as Markdown

Every built page also gets its own original `.md` source published
alongside it (`docs/guides/deployment.md` → `site/guides/deployment.md`,
next to `site/guides/deployment/index.html`) - a "Download Markdown" link
appears on the page itself, next to "Edit this page." Always on, no config.

## Build, serve, clean

```bash
bxSites build           # render docs/**.md into site/
bxSites serve           # build and serve locally with live reload
bxSites clean           # remove site/ and .cache/ (asks first)
bxSites clean --force   # skip the prompt - needed in CI
```

`clean` asks `Delete site/ and .cache/ in <root>? [y/N]` and prints
"Nothing to clean" if neither folder exists. With a closed stdin (CI,
piped) and no `--force` it exits `1` and deletes nothing.

`serve` builds, serves `site/` at `http://127.0.0.1:8080/` by default
(`--port=`/`--host=`, or space-separated, to change), and rebuilds
automatically on any saved change under the content root, the site config,
or a project `.theme/` override - a
native file watcher, only reconverting what changed, so it stays fast even
on a large site. See `bx-sites-build` for `doctor`/`stats`/`audit` and a
CI-grade pre-publish gate, and `bx-sites-deployment` for shipping the
result.

## Agent instruction files

```bash
bxSites agents:sync [--agents=agents,claude,cursor]
```

Retrofits or refreshes `AGENTS.md`/`CLAUDE.md`/`.cursorrules` inside a
`<!-- bxsites:agents:start -->`/`<!-- bxsites:agents:end -->` marked block;
a file without the markers is skipped, never overwritten, and
`.markdownlint.json` is always rewritten. Details in `bx-sites-ai-features`.

## CLI basics

- `bxSites help`, `-h`, `--help` print the verb list; `-v`/`--version` print
  the version; bare `bxSites` prints the usage and exits `1`.
- The CLI exits non-zero on any failure (an error prints `Error: ...` and
  exits `1`).
- The site config is looked up as `bxsites.yaml`, `.yml`, `.toml`, then
  `.json` - the first one found wins.

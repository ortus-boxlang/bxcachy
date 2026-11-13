---
name: bx-sites-build
metadata:
  version: "1.0"
description: Build, serve, and diagnose a bx-sites (ortus-boxlang/bx-sites) site - build/serve/clean/search-index, doctor (environment/config health), stats (page/word/blog/search-index/output-size report), and audit (broken internal links/images, missing alt text, orphaned pages) against an already-built site/. Use this whenever a user wants to run/troubleshoot a bx-sites build, verify a build actually produced valid output, or get a CI-grade quality gate before deploying. For Markdown source checks that don't need a build, use bx-sites-content-quality; for shipping site/ somewhere, use bx-sites-deployment.
---

# BxSites Build & Diagnostics

Every command runs as `bxSites <verb> [options]` (or
`boxlang bxSites <verb> [options]` where the `PATH` shim isn't installed -
e.g. a CI runner). Every verb accepts `--projectRoot=<path>`.

## `build`

```bash
bxSites build
```

Renders the configured content root (the `source` key, else `docs/` then
`src/`) into a static site in `site/`, skipping dot-prefixed items and the
config's `exclude:` list; it throws `BxSites.SourceNotConfigured` if no
content root resolves. Also builds the search index (unless `search:
false`, or `searchProvider` is set to a provider like `algolia`/`pagefind`
that doesn't use it - see `bx-sites-search`), runs the `pagefind` CLI
against the finished `site/` when that provider is active, and copies theme
+ the content root's `assets/**` into `site/`.

A multi-tree build (each `docs/versions/<name>/` and each
`docs/i18n/<code>/`) renders those trees **in parallel** rather than one
after another, so a site with several locales/versions costs roughly as much
as its slowest tree, not the sum of them. A failure inside any parallel tree
is surfaced as that real error and fails the build - it's never swallowed
into a "successful" run, which matters on a large site where the broken tree
isn't the one you were watching.

On success `build` prints a **Build report**: duration, page count (with
version/locale counts), output file count and size, and per-phase timings.

## `serve`

```bash
bxSites serve [--port=8080] [--host=127.0.0.1]
```

Builds and serves `site/` locally with live reload. Runs in the foreground
until interrupted (Ctrl+C). `--port 9191 --host 127.0.0.1` (space-separated)
works too; a non-numeric port falls back to `8080`. A native BoxLang file
watcher (not a poll loop) watches the content root, the site config file
and the content root's `.theme/`, reacts to a saved change immediately, and
only reconverts the page(s) that actually changed rather than the whole
site.

## `search-index`

```bash
bxSites search-index
```

Rebuilds `site/search-index.json` standalone, without re-rendering pages or
copying assets - `build` already runs this automatically; this verb exists
for when only the index needs refreshing. Only ever covers the main `docs/`
tree, even on a project with `docs/versions/`/`docs/i18n/` - a real `build`
writes each tree's own scoped index instead. No-op for the `algolia`/
`pagefind` search providers (neither uses a local index) - see
`bx-sites-search`. When it skips (search off, or one of those providers) it
prints "Search is disabled ... nothing to index" and exits `0`.

## `clean`

```bash
bxSites clean
bxSites clean --force
```

Removes `site/` and `.cache/`, leaving the content folder and the site
config alone. It asks `Delete site/ and .cache/ in <root>? [y/N]` first;
`--force` skips the prompt and is needed in CI. With a closed stdin (CI,
piped) and no `--force` it exits `1` and deletes nothing. If neither folder
exists it prints "Nothing to clean".

## `doctor`

```bash
bxSites doctor
```

A one-shot environment/config health check - the "run this before filing a
bug report" verb. Prints one line per check: the JVM version, that the
resolved content root exists (`source`, else `docs/`/`src/`), that the site
config (`bxsites.yaml`/`.yml`/`.toml`/`.json`) actually parses and
validates, that the required BoxLang modules (`bx-markdown`, `bx-esapi`,
`bx-yaml`, `bx-image`) are installed and activated, and - if a content-root
`.theme/` override exists - that it satisfies the `layout.bxm`/`page.bxm`
contract (see `bx-sites-themes`).

Two checks are conditional: `bx-toml` only when `bxsites.toml` or a
`data/*.toml` file exists, and `bx-ftp` only when a `deployments/` entry
targets `ftp`/`sftp`. A missing one fails with an
`install-bx-module <name>` hint. Exits `1` if any check fails, `0`
otherwise. Nothing here mutates a project.

## `stats`

```bash
bxSites build
bxSites stats
```

A read-only summary report of an already-built `site/` (run `build` first).
Reports:

- Total page/word counts, plus a per-tree breakdown once there's more than
  one tree (a version, or a non-default locale)
- Version/locale names present
- Blog post/category/author/year-active counts (`none` if no blog)
- Distinct tag count across the whole site
- Search-index entry count and file size (`none` if search is off or a
  non-local provider is active)
- Total file count and on-disk size of the built `site/`

Always exits `0` - purely informational, not a pass/fail gate (that's
`audit`'s job).

## `audit`

```bash
bxSites build
bxSites audit
```

A CI-grade content quality gate over an already-built `site/` (run `build`
first; it throws `BxSites.SiteNotBuilt` if `site/` is absent). The verb is
`audit`, not `check` - BoxLang reserves `check` as its own CLI token. Checks
for:

- **Broken internal links/images** - any `<a href>`/`<img src>` pointing at
  a page or asset that doesn't exist in `site/`. Fails the check.
- **Missing alt text** - any `<img>` with no `alt` attribute at all. An
  empty `alt=""` (correct markup for a purely decorative image) is not
  flagged. Fails the check.
- **Orphaned pages** - pages in `site/` not reachable by following links
  from any tree's own homepage. Informational only, never fails the check -
  a page deliberately left out of nav (frontmatter `hidden: true`) is
  *supposed* to only be reachable by direct link. `404.html` and
  `tags/index.html` are always exempt.

Exits `1` when there are broken links/images or missing-alt images, `0`
otherwise (orphaned pages never affect the exit code). Deliberately
internal-links-only - no HTTP requests to check external URLs.

## A CI-grade pre-publish gate

```bash
bxSites build
bxSites audit
bxSites stats
```

`audit` catches broken content; `stats` gives a sanity-check summary before
handing off to `bx-sites-deployment`. See `bx-sites-content-quality` for
`lint`/`blog:drafts`/`blog:find`/`search:query`, which check Markdown
source without needing a build first.

## Exit codes and failures

BoxLang 1.18+ is the minimum, and `--help`/`-h`/`--version` now reach
bx-sites instead of being intercepted by BoxLang. `main()` passes any
non-zero result to `cliExit()`, so a failing verb exits non-zero. A thrown
error prints `Error: ...` and exits `1`, and a failure in any parallel
version/locale tree fails the whole build.

As defence in depth, a CI job can still confirm `site/` is non-empty after
`build`, and run `doctor`/`audit` to catch a config or content problem the
build step didn't surface.

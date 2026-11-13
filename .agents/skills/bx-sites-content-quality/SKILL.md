---
name: bx-sites-content-quality
metadata:
  version: "1.0"
description: Check content quality in a bx-sites (ortus-boxlang/bx-sites) project without a full build - lint (heading-level skips, invalid blog post dates), list/filter draft and published blog posts (blog:drafts, blog:find), and sanity-check the search index (search:query). Use this whenever a user wants to validate Markdown source before a build, find draft or specific blog posts, or test what a search query would surface. For build-time checks on the rendered site/ (broken links, missing alt text, stats, environment health), use bx-sites-build instead.
---

# BxSites Content-Quality Checks

Author-facing checks over Markdown source, run before (or instead of) a
full build. Every command runs as `bxSites <verb> [options]` (or
`boxlang bxSites <verb> [options]`) and accepts `--projectRoot=<path>`.

`lint`, `blog:drafts` and `blog:find` read the project's configured content
root (the `source` key, default `docs/` then `src/`, not a hardcoded
`docs/`) and fail with `BxSites.SourceNotConfigured` if it can't be
resolved. Run `bxSites doctor` first (see `bx-sites-build`) to confirm the
environment, config and content root are healthy.

## `lint`

Pre-build content quality pass over raw Markdown - distinct from `audit`
(see `bx-sites-build`), which only inspects an already-built `site/` and
throws `BxSites.SiteNotBuilt` if there isn't one.

```bash
bxSites lint
```

Checks for:

- **Heading level skips** - a page body jumping straight from `##` to
  `####` with no `###` in between (confusing structure, bad for
  accessibility). Lines inside a fenced code block are never mistaken for
  headings.
- **Blog post date issues** - a `blog/posts/**` post (under the content
  root) with a missing or invalid frontmatter `date` (a real `build` itself
  throws on this the moment it loads posts - `lint` surfaces it as a
  finding first instead).

Exits `1` when either check finds anything, `0` otherwise.

Scope limits: the heading check walks the main page tree only. It skips
`blog/`, `versions/`, `i18n/`, `includes/`, `assets/` and dot-prefixed
items, and it does not honour the config's `exclude:` list (only the
built-in default excludes). The blog-date check separately walks
`blog/posts/**`.

## `blog:drafts`

Lists every blog post whose frontmatter sets `draft: true` - a real `build`
always skips drafts, so this is the only place their existence is surfaced.

```bash
bxSites blog:drafts
```

Always exits `0`.

## `blog:find`

Filters blog posts by author/category/tag/date range, without running a
full build.

```bash
bxSites blog:find [--author=] [--category=] [--tag=] [--since=] [--until=] [--drafts]
```

- `--author`, `--category`, `--tag` - case-insensitive exact match against
  any of the post's own values
- `--since`, `--until` - a date; only posts on/after `--since` and/or
  on/before `--until` match
- `--drafts` - include draft posts too (excluded by default)

Every filter is optional and independent - passing none lists every
published post. Output is `N matching post(s):` then one
`- Title (relative/path.md, date)` line per post. A bad `--since`/`--until`
throws `BxSites.InvalidDate` and exits `1`; "No matching posts" (and
`blog:drafts`' "No draft posts") exit `0`. See
`bx-sites-blog-versioning-i18n` for post frontmatter.

## `search:query`

Runs a keyword query against an already-built `site/search-index.json` -
run `bxSites build` or `bxSites search-index` first (see `bx-sites-build`).

```bash
bxSites search:query --query="getting started" [--limit=10]
```

- `--query` (required) - space-separated search terms
- `--limit` - maximum results to return, defaults to `10` (a value of `0`
  or less also becomes `10`)

Scores each page by simple, case-insensitive per-term substring matching,
weighted title 10, tags 8, headings 5, body 1 (the same relative weighting
as the client-side search widget, but only an approximation of it, not its
fuzzy matching). Prints `- title (url) [score: N]` per hit, best first, or
`No results for [q]`. See `bx-sites-search` for the underlying providers -
this verb only ever reads the main tree's `site/search-index.json`, not a
version/locale tree's own.

It is **not** a no-op with `search: false` or the `algolia`/`pagefind`
providers: it only checks for the file. With no `site/search-index.json` it
throws `BxSites.SearchIndexNotBuilt` and exits `1`, so those projects have
nothing to query.

## A typical pre-publish content pass

```bash
bxSites doctor             # environment/config pre-flight - see bx-sites-build
bxSites lint
bxSites blog:drafts        # confirm nothing meant to be published is still draft
bxSites build
bxSites audit  # broken links/alt text - see bx-sites-build
```

`bxSites new` and `agents:sync` also write a `.markdownlint.json` tuned for
bx-sites content (long lines, hard tabs, bare URLs and untagged code fences
are allowed; heading order and list rules stay on), so a standalone
markdownlint run or editor plugin doesn't flag ordinary bx-sites Markdown.
See `bx-sites-ai-features`.

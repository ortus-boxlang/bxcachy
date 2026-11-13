---
name: bx-sites-search
metadata:
  version: "1.0"
description: Configure and troubleshoot search in a bx-sites (ortus-boxlang/bx-sites) site - the default local static/client-side provider (MiniSearch, search-index.json, enriched results with breadcrumbs/snippets/match highlighting, / and Cmd/Ctrl+K shortcuts with arrow-key navigation), Algolia DocSearch, Pagefind, and wiring up a fully custom provider (e.g. Meilisearch) via a theme override. Use this whenever a user wants to turn search on/off, switch providers, or debug why search results look wrong.
---

# BxSites Search Providers Reference

`search: true`/`false` (in `bxsites.yaml` - see `bx-sites-configuration`) is
the master on/off switch regardless of which `searchProvider.provider` is
active.

## `local` (default)

Fully static/client-side - the mkdocs default approach. At `build` time,
`SearchIndexer` writes `site/search-index.json`: one entry per page with
`title`, `url`, frontmatter `tags`, every heading's text, a plain-text body
copy truncated to 400 characters, plus that page's `section` (its top-level
ancestor's title) and `breadcrumb` (the ancestor-title chain) used for result
display - so each entry is `{ title, url, headings, body, tags, section,
breadcrumb }`. `hidden` pages are left out. In the browser, `assets/search.js` fetches it once and builds a
[MiniSearch](https://lucaong.github.io/minisearch/) index (prefix +
typo-tolerant fuzzy matching, both on by default; title weighted highest,
then tags, then headings, then body). No server/database/external service.

**What a result looks like** - both the sidebar dropdown and the command
palette render the same enriched row, so a reader can tell hits apart
without opening each one:

- the page title, with the **matched terms highlighted** (highlighting
  follows the site's configured accent color, so it survives re-theming)
- a **breadcrumb line** - the entry's own ancestor titles joined with `›`
  (empty for a top-level page)
- a **body snippet**, built from the matched region of the indexed body

**Shortcuts**: `/` focuses the sidebar box (which shows a `Ctrl K`/`Cmd K`
hint badge); Cmd/Ctrl+K opens a
command-palette overlay (reuses the same MiniSearch index, `local` only);
`Escape` closes either (and blurs the sidebar box). In both, **Arrow
Up/Down** move the active highlight through results, **Enter** opens the
highlighted (or first) result, and hovering a result moves the highlight to
it as well.

```bash
bxSites search-index
```
rebuilds just the index (`build` already runs this; useful standalone - see
`bx-sites-build`). `bxSites search:query --query="..."` (see
`bx-sites-content-quality`) sanity-checks what a real search would surface.

**Index scoping**: a full `build` writes one `search-index.json` per doc tree -
the main tree, each `versions/<v>/`, and each locale - so a versioned or
localized site only searches the tree the reader is on. The standalone
`search-index` verb covers only the main tree. `search: false` ships no index,
no search box, and no MiniSearch/`search.js` at all.

Everything a result shows - title, breadcrumb, snippet - comes from that
build-time file, so a page that moved/re-nested keeps showing its old
breadcrumb until the next `build` (or `search-index`).

## `algolia`

```yaml title="bxsites.yaml"
search: true
searchProvider:
  provider: algolia
  algolia:
    appId: ABC123
    apiKey: a1b2c3d4e5f6...   # search-only public key, NEVER an admin key
    indexName: my-docs
    insights: false
```

`appId`/`apiKey`/`indexName` required. With Algolia active: no
`search-index.json` is built, no MiniSearch/`search.js` shipped - results
come from Algolia's own hosted index, populated by DocSearch's crawler or
your own Algolia Crawler config (register separately - bx-sites only wires
up the client widget). Each theme renders an empty
`#bxsites-search-algolia` container; `layout.bxm` loads `@docsearch/css`/
`@docsearch/js` from jsDelivr and calls `docsearch({...})`. Gets Cmd+K for
free from DocSearch itself. `insights`, when present, must be a boolean.

## `pagefind`

```yaml title="bxsites.yaml"
search: true
searchProvider:
  provider: pagefind
  pagefind: { bin: pagefind, options: [] }
```

Both keys optional (`bin` default `"pagefind"`, resolved against `PATH`, and
non-empty if given; `options` an array of non-empty strings, extra raw CLI
flags, e.g. `["--exclude-selectors", ".no-index"]`). Bootstrap's `layout.bxm`
binds Cmd/Ctrl+K to focus the Pagefind input (PagefindUI doesn't itself).
**The `pagefind` CLI must already be installed and on `PATH`** - bx-sites
shells out to it, doesn't install it. A missing/failing binary fails the
build loudly (`BxSites.PagefindFailed`) rather than degrading silently.
Right after every doc tree + `sitemap.xml`/`llms.txt` are written, bx-sites
runs `pagefind --site <siteDir> [...options]` against the *entire* built
`site/` (indexes a multi-version/multi-locale site in one pass, unlike
`local`'s per-tree index - see `bx-sites-blog-versioning-i18n` for
versions/locales). Writes into `site/pagefind/` - self-hosted, no CDN. No
`search-index.json`; `bxSites search-index` is a no-op for this provider.

## Choosing a provider

| | `local` | `algolia` | `pagefind` |
|---|---|---|---|
| Server/account | No | Yes (Algolia) | No |
| Indexed from | `search-index.json` | Algolia's hosted index | Built `site/` HTML |
| Fuzzy/prefix | Yes (MiniSearch) | Yes (Algolia) | Yes (Pagefind) |
| Extra install | None | None (client-only) | `pagefind` CLI on `PATH` at build time |
| Best for | Most projects, zero setup | Large sites wanting hosted analytics/tuning | Large multi-version/multi-locale sites, full-page indexing, no hosted account |

## Building a fourth/custom provider

`searchProvider.provider` accepts any non-empty string (it is the one required
key of `searchProvider`) - `bxsites.yaml` only validates the `algolia` and
`pagefind` sub-blocks and freely allows an arbitrary sub-block alongside it
(`searchProvider.meilisearch: {...}`). There's no plugin hook for the search UI
itself, so wiring one up is a project-level theme override (see
`bx-sites-themes`). What a built-in theme already does for an unrecognized
provider differs:

- **`bootstrap`**'s `search.bxm` renders `<div id="bxsites-search-<provider>"
  class="bxsites-search-<provider>">` for *any* provider that isn't `local`, so
  the mount point already exists - don't add a duplicate id.
- The **other 9 themes** branch only on `algolia`/`pagefind`/`local` in
  `search.bxm` and render nothing for anything else.

1. **Configure it** - any shape (unvalidated):
   ```yaml
   search: true
   searchProvider:
     provider: meilisearch
     meilisearch: { host: https://my-project.meilisearch.io, apiKey: "...", indexName: my-docs }
   ```
2. **Eject a theme** - `bxSites theme:new --theme=bootstrap` copies the
   built-in theme into the project's `.theme/` folder, inside the resolved
   content root (project-theme-wins resolution - see `bx-sites-themes`).
3. **Add the mount point** (non-bootstrap themes only) in
   `.theme/search.bxm` - it branches on `variables.searchProviderName` for
   `local`/`algolia`/`pagefind`; add a branch: `<bx:if variables.searchProviderName
   eq 'meilisearch'><div id="bxsites-search-meilisearch"></div></bx:if>`.
4. **Load the client and wire it up** - the existing Algolia/Pagefind blocks
   are `<bx:if variables.searchEnabled and variables.searchProviderName eq
   'algolia'>` guards; add the equivalent for the new provider's own widget,
   reading its config back out of `variables.siteConfig.searchProvider.meilisearch.*`.
   Mind *which shells carry search blocks*: an ejected bootstrap theme has
   `layout.bxm` and `blog.bxm`, each with its own `searchProviderName` blocks
   in the `<head>` (CSS, local-search scripts) and again near the end of
   `<body>` (the Algolia/Pagefind widget init), plus `home.bxm` with the
   `<head>` block only (no widget-init block). A provider wired only in
   `layout.bxm` is missing on blog pages and the homepage; add it to each shell
   that renders search. The other 9 themes have just `layout.bxm`.
5. **Index the built site, if not crawler-hosted** - Algolia's own crawler
   populates out of band; a self-hosted engine like Meilisearch/Pagefind
   needs something to push documents after `build` writes `site/`. Use a
   plugin's `onBuildComplete( siteDir, config )` hook (see
   `bx-sites-plugins`) - `site/search-index.json` is still built even for
   an unrecognized provider (`SearchProviderRegistry.usesLocalIndex()`
   defaults `true`), so it's ready to use as the push payload.

## Config validation

`ConfigLoader` rejects with `BxSites.InvalidConfig`: `searchProvider` without a
non-empty `provider`; `algolia` without non-empty `appId`/`apiKey`/`indexName`
or with a non-boolean `insights`; `pagefind` that isn't an object, with an
empty `bin`, or with `options` that isn't an array of non-empty strings.

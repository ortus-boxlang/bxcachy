---
name: bx-sites-configuration
metadata:
  version: "1.0"
description: Full bxsites.yaml/bxsites.toml/bxsites.json key reference for a bx-sites (ortus-boxlang/bx-sites) project - baseURL, source, exclude, robots.txt, nav, redirects, markdown options, repo/social/footer, lastUpdated, analytics, ogImage/generateOgImages, extraCss/extraJs, the assets/image pipeline, pageActions, mermaid/math/openapi/imageGallery, versions.default, mcp, and the plugins/i18n/blog/variables/docbox/coldbox/cloud keys. Use this whenever a user asks what a bxsites.yaml/.toml key does, how to set the site's base URL/sub-path, how to customize the nav, or wants to tune the responsive-image/asset-bundling pipeline. For themes, search providers, and deployment/publish config, use bx-sites-themes/bx-sites-search/bx-sites-deployment instead; for docbox/coldbox and mcp/AI-agent-skills detail, use bx-sites-api-docs/bx-sites-ai-features.
---

# BxSites Configuration Reference

One site config at the project root: `bxsites.yaml` (or `.yml`, default/
preferred), `bxsites.toml`, or `bxsites.json` - all three fully supported,
same keys, same defaults (YAML needs the bx-yaml module, TOML config or
`docs/data/*.toml` needs bx-toml; BoxLang 1.18+ is the minimum runtime, and
the CLI exits non-zero on any failure). If more than one is present, `bxsites.yaml` wins,
then `bxsites.yml`, then `bxsites.toml`, then `bxsites.json`. Only `name` is
required - everything else defaults as shown. A partial `theme` object
merges one level deep (`{theme: {name: material}}` keeps the default empty
`options`).

```yaml title="bxsites.yaml - every key and its default"
name: "My Docs"
description: ""
baseURL: "/"
source: docs
exclude: []
theme:
  name: bootstrap
  options: {}
  logo: ""
  favicon: ""
search: true
mcp: false
searchProvider:
  provider: local
  algolia: { appId: "", apiKey: "", indexName: "", insights: false }
  pagefind: { bin: pagefind, options: [] }
nav: []
markdown:
  enableAdmonition: true
redirects: []
repo:
  url: ""
  editUri: ""
social: []
footer: false
lastUpdated: false
robots: true
mermaid: false
math: false
openapi: false
imageGallery: false
analytics:
  provider: ""
  id: ""
ogImage: ""
generateOgImages: false
extraCss: []
extraJs: []
assets:
  fingerprint: true
  bundle: true
  images: { enabled: true, widths: [400, 800, 1200, 1600], formats: [original, webp] }
pageActions: false
plugins: []
i18n:
  defaultLocale: { code: en, label: English }
  locales: []
blog:
  postsPerPage: 10
  feed: true
  feedLimit: 25
versions:
  default: ""
variables: {}
cloud:
  siteId: ""
  apiUrl: ""
  contentBlocks: false
  contentBlocksOnError: fail
  comments: false
docbox:
  projectTitle: ""
  mappings: {}
  excludes: ""
  pagePathPrefix: api/docbox
  tags: [api, docbox]
coldbox:
  appRoot: ""
  pagePathPrefix: api/coldbox
  tags: [api, coldbox]
  include: [routes, handlers, models, modules, interceptors, scheduler]
```

All three formats use the identical key names/shapes - only the syntax
differs. TOML nests the same way YAML/JSON do, using `[section]`/
`[[section]]` (array-of-tables) headers:

```toml title="bxsites.toml"
name = "My Docs"
baseURL = "/"

[theme]
name = "material"

[[nav]]
title = "Reference"
children = [ "api/docbox/index.md" ]
```

## `name` / `description`

`name` (required) - site name, shown in header/brand mark and page titles.
`description` - fallback `<meta name="description">`/`og:description` for
any page without its own `description` frontmatter, then `summary`, then a
derived excerpt (see `bx-sites-getting-started` for page frontmatter).

## `baseURL`

Controls prefixing for every internal link/asset/nav entry, and doubles as
the canonical URL for `sitemap.xml`/`robots.txt`/`llms.txt`/canonical tags.

- **Blank or `"/"`** (default) - root-relative links (`/page/`); no
  `sitemap.xml`, no `Sitemap:` line, no canonical tags (no domain to build
  them from).
- **A bare path** (`"my-docs"` or `"/my-docs/"`) - sub-path served
  (`/my-docs/page/`); still no sitemap/canonical (no absolute domain).
- **A full URL** (`"https://docs.example.com/"`) - the path portion is used
  the same as a bare path, **and** `sitemap.xml`/`robots.txt`'s `Sitemap:`
  line/every page's `<link rel="canonical">` are generated. A version/locale
  tree points its canonical at its own URL, not the main site's.

`llms.txt` is always written regardless (absolute URLs when `baseURL`
provides them, `basePath`-relative otherwise).

## `source`

Which folder holds the project's content - `docs`, `src`, any custom folder
name, or `.` (whole repo is the content, no subfolder). Unset (default) -
`docs/` then `src/` auto-detected; if neither exists on disk **and**
`source` is unset, resolving throws `BxSites.SourceNotConfigured` instead of
guessing. `bxSites new` always writes an explicit `source:`. `.theme`/
`.themes/<name>` theme overrides (see `bx-sites-themes`) live inside this
resolved content root, not the bare project root - important for a
multi-domain monorepo where several project roots share one repo.
`source: site` is rejected (`site/` is the generated output folder).

## `exclude`

`[]` default - extra entries to leave out of the content scan. Matching is
**anchored at the content root**, not a bare name at any depth: an entry is
a root-level file/folder name or a root-relative path prefix (`internal/
drafts`), checked as `^<entry>(/|$)` in `DocsLoader.bx`. Always excluded
regardless: `.git`, `.github`, `boxlang_modules`, `node_modules`, `site`,
`.theme`, `.themes`, `bxsites.yaml`/`.yml`/`.toml`/`.json`, `box.json`, and
**any** dot-prefixed file or folder. `assets/`, `versions/`, `i18n/`,
`blog/` and `includes/` are handled separately in every tree. Deliberately
does **not** auto-exclude `README.md`/`LICENSE.md`/`CHANGELOG.md` - a project
can have a real content page at that name; a `source: .` project not wanting
its root README/LICENSE/CHANGELOG published opts out via `exclude` instead.

## `robots.txt`

`robots: true` (default) writes `Allow: /` for every crawler plus a
`Sitemap:` line (when `baseURL` is a full URL). `robots: false` writes
`Disallow: /` and no `Sitemap:` line - a crawler opt-out only, **not access
control** (the site is still fully reachable by URL - see
`bx-sites-deployment` for real access restriction). Drop a hand-authored
`docs/robots.txt` to bypass the generated one entirely (copied byte-for-byte,
`robots` key ignored once this file exists).

## `theme`

- `theme.name` - one of the ten built-in themes (`bootstrap` default,
  `material`, `tailwind`, `docsy`, `slate`, `docusaurus`, `justthedocs`,
  `vuepress`, `gitbook`, `notion`) or an installed/custom theme's name - see
  `bx-sites-themes`. Must be a slug (lowercase letters, digits, hyphens);
  per-theme changes live in `.overrides/<theme.name>/`
- `theme.logo`/`theme.favicon` - path (resolved against `docs/assets/`,
  prefixed with `baseURL`) or absolute URL
- `theme.options.colorMode` - `"auto"` (default, follows OS)/`"light"`/`"dark"`
  first-visit default; a visitor's own toggle choice always wins after
- `theme.options.navCollapsible` - `false` (default): every nav section
  always expanded. `true`: sections get a collapse toggle; the section
  containing the current page always starts open.
- `theme.options.navExpandAll` - only with `navCollapsible: true`. `true`
  (default): every section starts open. `false`: every section starts
  collapsed except the current page's.
- `theme.options.tocPosition` - `"top"` (default, inline at article top) or
  `"sticky"` (pinned right-hand column on wide viewports; a collapsible
  top-pinned bar below that width)
- `theme.options.pageMetaPosition` - `"bottom"` (default, footer note) or
  `"top"` for the edit-page/download-markdown/last-updated row
- `theme.options.pageActionsPosition` - `"top"` (default) or `"bottom"` for
  the [`pageActions`](#pageactions) dropdown
- `theme.options.breadcrumbs` - `true` (default) renders the
  "Guides > Setup" trail above a page's own title whenever it's nested more
  than one level deep; `false` turns breadcrumbs off site-wide
- `theme.options.accentColor` / `theme.options.accentColorDark` - a 3- or
  6-digit hex (e.g. `"#2563eb"`) overriding the theme's interactive/accent
  color (links, active nav items, focus states) for light / dark mode
  respectively. Either can be set alone - an unset one keeps that mode on the
  theme's own native accent. Site-wide and build-time; there's no
  visitor-facing UI to change them, and no effect on a theme that ignores
  them - for palette work across every theme, use `extraCss` instead (see
  `bx-sites-themes`)
- `theme.options.navAccentLine` - `true` (default) draws a thin vertical
  line alongside a nested sidebar nav section; `false` turns it off.
  `navAccentLineColor` (3- or 6-digit hex) overrides its color, falling back
  to `accentColor`/`accentColorDark`, then the theme's native accent

## `layouts`

Implicit layouts: `[{ layout: landing, match: ["marketing/**", "pricing.md"] }]`
assigns a layout to every page whose content-root-relative path matches a glob
(first rule wins; a page's own `layout:` frontmatter wins over a rule). `layout`
is a bare template name; `match` is a glob or a list. Default `[]`. See
`bx-sites-themes` ("Implicit layouts").

## `search` / `searchProvider`

`search: true`/`false` is the master switch regardless of provider.
`searchProvider.provider`: `"local"` (default, MiniSearch + static index),
`"algolia"` (needs `algolia.appId`/`apiKey`/`indexName`), `"pagefind"`
(`pagefind.bin`/`options`, both optional), or any other string for a fully
custom provider wired via a theme override. Full comparison and setup in
`bx-sites-search`.

## `nav`

Empty array (default) = infer from `docs/`'s folder/file structure (honoring
page `order`/`hidden` frontmatter). A non-empty array replaces inference
entirely - array order becomes nav order; a page not referenced is still
built, just unlinked (same as `hidden: true`). Each entry is either:

- a bare `docs/`-relative path string (`"guides/setup.md"`), title from that
  page's own frontmatter/filename
- an object `{ title, path, icon, children }` - `path`/`icon`/`children` all
  optional; a `title`-only entry with no `path` is an unlinked group
  heading; explicit `title`/`icon` override the page's own nav label/icon
  (the page's real `<h1>`/`<title>` is untouched)

```yaml title="bxsites.yaml"
nav:
  - index.md
  - title: Main Components
    children:
      - title: Quick Start
        path: guides/setup.md
      - guides/deployment.md
```

For a nav large enough to clutter `bxsites.yaml`, move it to `docs/nav.json`
(same array shape as the whole file's top-level content) - `bxsites.yaml`'s
own non-empty `nav` always wins over it if both exist. Only the main tree
honors either; a `docs/versions/<name>/` tree always infers from its own
folder structure.

## `redirects`

Site-wide `from`/`to` pairs, main tree only. See the
`bx-sites-blog-versioning-i18n` skill for the full picture including the
per-page `redirect_from` frontmatter alternative.

```yaml title="bxsites.yaml"
redirects:
  - from: old-guide
    to: guides/new-guide/
```

## `markdown`

Forwarded as-is to bx-markdown - not redefined/validated by bx-sites beyond
`enableAdmonition` (bx-markdown itself defaults it `false`; bx-sites
defaults it `true`). See `bx-sites-markdown` for the syntax each key
controls.

| Key | Default | Effect |
|---|---|---|
| `enableAdmonition` | `true` | `!!!`/`???`/`???+` callouts |
| `enableFootnotes` | `false` | `[^label]` footnotes |
| `enableDefinitionLists` | `false` | `Term\n:   Definition` lists |
| `autoLinkUrls` | `true` | Auto-links bare URLs/emails |
| `anchorLinks` | `true` | Clickable anchor link per heading |
| `anchorSetId` / `achorSetName` *(sic)* | `true` | `id`/`name` attrs on headings |
| `anchorWrapText` | `false` | Wraps whole heading text in the anchor |
| `anchorClass` | `"anchor"` | CSS class on the anchor `<a>` |
| `anchorPrefix` / `anchorSuffix` | `""` | Raw HTML before/after heading text |
| `enableYouTubeTransformer` | `false` | Auto-embeds bare YouTube links |
| `codeStyleHTMLOpen`/`Close` | `<code>`/`</code>` | Inline code wrapper |
| `fencedCodeLanguageClassPrefix` | `"language-"` | Class prefix highlighter/Mermaid key off |
| `tableOptions.columnSpans` | `true` | Honors `colspan` merged cells |
| `tableOptions.appendMissingColumns` | `true` | Pads a short row |
| `tableOptions.discardExtraColumns` | `true` | Drops a long row's extra cells |
| `tableOptions.className` | `"table"` | CSS class per `<table>` |
| `tableOptions.headerSeparationColumnMatch` | `true` | `---` row must match header column count |

## `repo`

`repo.url` adds a header repo-icon link. `repo.editUri` (e.g.
`"edit/main/docs/"`) plus `repo.url` builds an "Edit this page" link per
page.

## `social` / `footer`

`social` - array of `{ url, icon, label }`, rendered in the footer only when
`footer: true`. `icon` is one of `github`/`twitter`(`x`)/`youtube`/
`linkedin`/`facebook`/`bluesky`/`threads`/`slack`/`patreon`/`rss`/`email`
(generic link glyph otherwise). `footer: true` adds a copyright line, the
`social` links, and a "Built with BxSites" credit to every page.

## `lastUpdated`

`false` default. `true` adds a "Last updated" line sourced from `git log` on
each page's own file at build time - silently omitted where git has no
history for it (fresh repo, zip download, no git installed), rather than
breaking the build.

## `analytics`

Google Analytics only currently: `provider: "google"` + `id: "G-ABC123"`
(`id` letters, digits and hyphens only).

## `ogImage` / `generateOgImages`

`ogImage` - default social-card image (path resolved like `theme.logo`, or
absolute URL); a page's own frontmatter `ogImage` always wins for that page.
`generateOgImages: true` renders a real 1200x630 PNG per page lacking its
own `ogImage`. Drawn with the `bx-image` module (1.13.0 or later), so no
headless browser or network is needed. Each card has the site logo and name, a
section chip, the page title, its description and URL, and an accent gradient
bar; accent colors come from `theme.options.accentColor`/`accentColorDark`.

`ogCard` (optional object, every key optional) tunes the cards:
`background`, `accent`, `accentEnd`, `text`, `muted` (`#RGB`/`#RRGGBB`),
`logo` (PNG/JPG/GIF; SVG cannot be drawn, so the card falls back to the site
name), `font` (a TTF/OTF in the source folder or an absolute path), and the
booleans `description`, `url` and `section` (all default `true`).

```yaml
generateOgImages: true
ogCard:
  background: "#06141a"
  logo: assets/og-logo.png
  description: true
```

## `extraCss` / `extraJs`

Arrays of stylesheet/script URLs appended after the theme's own assets, each
resolved like `theme.logo`. `extraJs` entries load with `defer`. When
`assets.bundle` is on (default) and every entry is a local project file,
they're bundled into one fingerprinted file each instead of one tag per
entry - one external/missing entry falls the whole list back to per-URL tags.

## `assets`

The image-resizing/bundling pipeline, on by default with sane settings -
usually nothing to touch.

- `assets.fingerprint` (`true`) - content-hash names generated variants/
  bundles **and any top-level CSS/JS file** in the active theme's `assets/`
  and the module's shared assets (e.g. `style.<hash>.css`,
  `copy-code.<hash>.js`; not subdirectories) for safe far-future caching, so
  a theme update busts every visitor's cache on the next deploy with no
  manual versioning; never renames a project's own originals under
  `docs/assets/` (so `::: file` cards and plain-filename links keep
  working).
- `assets.bundle` (`true`) - concatenates `extraCss`/`extraJs` into one
  fingerprinted file each (pure BoxLang/JVM, no Node toolchain).
- `assets.images.enabled` (`true`) - resize/WebP + `<picture>` rewrite for
  eligible images; `false` falls back to plain unprocessed copying.
- `assets.images.widths` (`[400, 800, 1200, 1600]`) - breakpoints; a width
  at/above an image's own is skipped (never upscaled).
- `assets.images.formats` (`["original", "webp"]`) - only `original` and
  `webp` are accepted.

## `mermaid` / `math` / `openapi` / `imageGallery`

All `false` by default - `true` loads the client-side library (Mermaid/
KaTeX/Swagger UI/lightbox) and activates the corresponding Markdown
syntax. See `bx-sites-markdown` and `bx-sites-content-blocks` for the
syntax itself.

- `mermaid: true` renders ` ```mermaid ` fenced blocks as diagrams.
- `math: true` typesets `$inline$`/`$$block$$` with KaTeX.
- `openapi: true` renders every `::: openapi src="..."` block as an
  interactive Swagger UI widget; unset, the placeholder renders but stays
  inert and ships no extra JS/CSS.
- `imageGallery: true` loads a small click-to-enlarge lightbox that makes
  **every** content image zoomable (arrows cycle all zoomable images on the
  page), not only `::: image-gallery` blocks. Opt an image out with
  `class="no-zoom"` or `data-no-zoom`. Unset, the gallery grid still
  renders, just without the lightbox's JS.

## `pageActions`

`false` default. `true` adds a "Copy" dropdown (Copy page/link, View as
Markdown, Open in ChatGPT/Claude, Export as PDF, Report an issue, Share on
X/LinkedIn/Facebook) - press `c` to toggle it too. Several sub-items only
render when their prerequisite is set (`baseURL` full URL for link/share
items, `repo.url` for "Report an issue"). No extra JS shipped unless this is
on.

## `plugins`

`[]` default - array of BoxLang module names to activate. See
`bx-sites-plugins`.

## `mcp`

`false` default (the `mcp` key above). `true` writes `site/mcp-index.json`/`mcp-manifest.json`/
`mcp-nav.json` on every build, for bxSites Cloud's AI-agent MCP server -
independent of `search`/`searchProvider`. See `bx-sites-ai-features`.

## `docbox` / `coldbox`

Settings for `bxSites docbox` (a BoxLang/CFML API reference via DocBox) and
`bxSites coldbox` (a ColdBox app's routes/handlers/models/modules read from
disk) - `mappings`/`excludes`/`pagePathPrefix`/`tags` for the former,
`appRoot`/`include`/`pagePathPrefix`/`tags` for the latter, defaults as in
the key block above. `docbox.projectTitle` titles the generated overview
page (default: the site `name` plus `" API"`). Every key is optional; see
`bx-sites-api-docs` for the full schema and generated output.

## `cloud`

`cloud.siteId`/`cloud.apiUrl` - where `bxSites publish` ships the built
site in bxSites Cloud. Both default to `""`; only `publish` needs them. The
API token never lives here - see `bx-sites-deployment`. Also:

- `cloud.apiUrl` is where `::: cloud` blocks fetch content at build time.
- `cloud.contentBlocks` (`false`) - ships the client-side runtime that
  live-refreshes `::: cloud` blocks. `true` with an empty `apiUrl` throws
  `InvalidConfig`.
- `cloud.contentBlocksOnError` - `"fail"` (default) or `"skip"`: what a
  `::: cloud` block does when its build-time fetch fails.
- `cloud.comments` (`false`) - gates `::: comments`; a bare block without it
  fails the build. Comments load client-side, so no `apiUrl` fetch is needed.

## `versions`

`versions.default: ""` (the default) - the plain `docs/` tree builds at the
site root, as always. Set it to a `docs/versions/<name>/` folder's own name
and **that** version builds at the site root instead, with `docs/` itself
building separately at `/next/` (still fully browsable, own search index,
excluded from `sitemap.xml`, and `robots.txt` gains a `Disallow: /next/`
line). A value that doesn't match any discovered version folder throws
`BxSites.UnknownDefaultVersion` - it never falls back silently. Creating a
version is still convention-only (`docs/versions/<name>/`, or
`bxSites version:new`) - see `bx-sites-blog-versioning-i18n`.

## Validation rules that bite

Bad values throw `BxSites.InvalidConfig` (ConfigLoader.bx) and fail the
build: `name` missing; `source: site`; `accentColor`/`accentColorDark` not a
3- or 6-digit hex; `colorMode` not `light|dark|auto`; `tocPosition` not
`top|sticky`; `pageMetaPosition`/`pageActionsPosition` not `top|bottom`;
`analytics.provider` anything but `google`, or an `analytics.id` with
characters beyond letters/digits/hyphens; an `i18n` locale `code` that isn't
letters/digits/hyphens starting with a letter, or a duplicate code (the
default locale counts); `assets.images.formats` entries other than
`original|webp`; `blog.postsPerPage` not a positive whole number;
`searchProvider.provider: algolia` without `appId`/`apiKey`/`indexName`;
a `theme.name` that is not a slug; a `layouts` that is not an array of
`{ layout, match }` entries, a `layout` that is not a bare template name, or an
empty `match`.

## `i18n` / `blog` / `variables`

See the `bx-sites-blog-versioning-i18n` and `bx-sites-variables-functions`
skills for the full picture - these keys are metadata/tuning for
content-authoring features, not build/deploy concerns. `i18n` also carries
each locale's `dir` (`"ltr"`/`"rtl"`), an optional `flag` emoji override, and
a `strings` map overriding that locale's theme-chrome UI text; `blog` also
carries `feedLimit` (default `25`, `0` = uncapped).

---
name: bx-sites-plugins
metadata:
  version: "1.0"
description: Write or install a bx-sites (ortus-boxlang/bx-sites) plugin - the models/BxSitesPlugin.bx build-lifecycle hooks (onConfig, onPageMarkdown, onPageHtml, onNav, onSearchIndex, onSitemap, onBuildComplete), installing a published plugin from ForgeBox, and registering new bxSites CLI verbs via models/BxSitesCliProvider.bx. Use this whenever a user wants to extend bx-sites' build pipeline with custom logic, or add a new bxSites <verb> command.
---

# BxSites Plugins Reference

A BxSites plugin is nothing more than another BoxLang module - its own
`box.json` + `ModuleConfig.bx`, installed as a sibling of `bx-sites` in the
same runtime. No plugin API to import, no separate registry - BoxLang's own
module system *is* the plugin system. Installing a module never activates
it as a plugin on its own:

```yaml title="bxsites.yaml"
plugins: [ myBxSitesPlugin ]
```

(see `bx-sites-configuration` for the `plugins` key)

## Installing a published plugin

```bash
bxSites install:plugin --name=bx-sites-plugin-analytics [--version=1.2.0]
```

Downloads from ForgeBox and extracts into
`boxlang_modules/bx-sites-plugin-analytics/` at the project root (BoxLang's
auto-loaded local-module convention - no `box`/CommandBox needed, no
`BOXLANG_HOME`/global install step). Loads it into the runtime immediately
and prints the real registered module mapping name (not always the same as
the ForgeBox slug) - add *that* name to `plugins`. Browse published plugins
under ForgeBox's `bxsites-plugins` category.

## Writing a plugin

One class beyond the usual module scaffolding: `models/BxSitesPlugin.bx`.
Every method is optional - bx-sites checks for each before calling it.

```bash
bxSites plugin:new --name=my-analytics-plugin [--dest=]
```

scaffolds `box.json`, `ModuleConfig.bx`, and a `models/BxSitesPlugin.bx`
whose stubs sit inside a commented-out `/* */` block - uncomment only the hooks
you need. It stubs just five of the seven hooks (`onConfig`, `onPageMarkdown`,
`onPageHtml`, `onNav`, `onBuildComplete`), not `onSearchIndex`/`onSitemap`, and
its `onConfig` stub is declared `string function` - change it to
`struct function` (the contract below). `examples/hello-plugin/` in the
bx-sites repo is a working reference but implements only `onPageHtml` and
`onBuildComplete`.

`--dest` resolves against the project root (relative paths and `~/` work);
the default is `<projectRoot>/<name>`. A non-empty destination fails with
`BxSites.PluginDestExists`. The module name is the camelCase of the slugified
name (`my-analytics-plugin` becomes `myAnalyticsPlugin`), and **that** is what
goes in `plugins`, not the `--name` you typed.

```bx title="models/BxSitesPlugin.bx"
class {

	struct function onConfig( required struct config ) {
		// Mutate/return the site config, right after bxsites.yaml is loaded.
		return arguments.config
	}

	string function onPageMarkdown( required string markdown, required struct page, required struct config ) {
		// Mutate a page's raw markdown body. Runs FIRST for each page, before
		// ::: include expansion, {{ }} variable resolution, and tab/math/code/
		// directive extraction - so you see unexpanded includes and {{ }} text.
		return arguments.markdown
	}

	string function onPageHtml( required string html, required struct page, required struct config ) {
		// Mutate a page's rendered HTML after conversion.
		return arguments.html
	}

	array function onNav( required array nav, required struct config ) {
		// Mutate the nav tree: array of { title, url, order, children } nodes.
		return arguments.nav
	}

	array function onSearchIndex( required array entries, required struct config ) {
		// Mutate search-index.json entries before it's written - each is
		// { title, url, headings, body, tags, section, breadcrumb }. Runs once per index actually
		// written (main + each version/locale tree using a local index).
		return arguments.entries
	}

	array function onSitemap( required array pages, required struct config ) {
		// Mutate the accumulated page list right before BOTH sitemap.xml and
		// llms.txt are built from it. Only urlPath/title/hidden need be set.
		return arguments.pages
	}

	void function onBuildComplete( required string siteDir, required struct config ) {
		// Fires once, after everything is written to siteDir. No return value.
	}

}
```

Hooks run in `plugins` array order; each hook's return value (except
`onBuildComplete`) replaces the value the next hook (or bx-sites itself)
sees - return the input unchanged if there's nothing to modify.
`onPageMarkdown`/`onPageHtml` run once per page, per doc tree - the main
`docs/` tree, every `docs/versions/<name>/`, and every `docs/i18n/<code>/`
(see `bx-sites-blog-versioning-i18n`). Trees render in parallel, so a hook
must not depend on the order trees are built in.
`onSearchIndex`/`onSitemap` exist specifically for content living outside
`docs/` altogether (e.g. a dynamically-served page a CLI-provider addon
adds) that would otherwise be invisible to search/sitemap/`llms.txt`.

The standalone `bxSites search-index` verb also loads plugins: it applies
`onConfig`, and fires `onPageMarkdown`/`onPageHtml`/`onSearchIndex`, but not
`onNav`/`onSitemap`. The dev server (`serve`) caches converted pages per source
file, so the markdown/HTML hooks may not re-fire for files that haven't
changed since the last rebuild (a config, theme, or plugin change clears the cache).

### Order of hook calls

```text
onConfig(config)
  -> build the nav tree
onNav(nav, config)
  -> for every page: onPageMarkdown(markdown, page, config) -> includes, {{ }}, extraction -> Markdown() -> onPageHtml(html, page, config)
  -> write site/
onSearchIndex(entries, config)
  -> write search-index.json
onSitemap(pages, config)
  -> write sitemap.xml + llms.txt
onBuildComplete(siteDir, config)
```

## Errors

- `BxSites.PluginNotFound` - a name in `plugins` isn't an installed/activated
  BoxLang module.
- `BxSites.InvalidPlugin` - the module exists but has no
  `models/BxSitesPlugin.bx`.

## Registering new `bxSites` CLI verbs (CLI providers)

`models/BxSitesPlugin.bx` only covers the build lifecycle. A module can also
register its own `bxSites <verb>` commands (e.g. a commercial `deploy`/
`cloud publish` addon) via a sibling `models/BxSitesCliProvider.bx` class
exposing one `verbs()` method - same `plugins` array activation, a different
file. A module can implement `BxSitesPlugin.bx`, `BxSitesCliProvider.bx`,
both, or neither.

```bx title="models/BxSitesCliProvider.bx"
class {
	struct function verbs() {
		return {
			"cloud:publish" : {
				class       : "models.cli.cloud.Publish@myBxSitesAddon",
				description : "Build (if needed) and publish via the configured deploy target"
			}
		}
	}
}
```

```bx title="models/cli/cloud/Publish.bx"
class {
	struct function run( struct options ) {
		// arguments.options carries the same parsed-flags-plus-projectRoot
		// shape every core verb receives.
		return { exitCode : 0, message : "Published #arguments.options.projectRoot#" }
	}
}
```

- **The `@myModuleMapping` suffix on the dispatch class path is required** -
  a bare dotted path like `"models.cli.cloud.Publish"` only resolves
  relative to `bx-sites`' own module root; a provider's own verb classes
  must self-supply their module's `@<mapping>` suffix to be reachable at all.
- **Verb names** are one colon-joined string (`"cloud:publish"`, the same
  convention core uses for `post:new`/`i18n:status`); `bxSites cloud publish`
  (two argv tokens) and `bxSites cloud:publish` dispatch identically once
  that name is registered - no separate two-word registration needed.
- **Core always wins** on a name collision with a built-in verb (the
  provider's entry is silently ignored - a provider can add commands, never
  shadow one). Between two providers, **first listed in `plugins` wins**.
  A missing/malformed config, no `BxSitesCliProvider.bx`, or a `verbs()`
  that throws never breaks core dispatch - it's treated like an unactivated
  plugin.

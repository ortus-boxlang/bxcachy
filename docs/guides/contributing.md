---
title: Contributing and docs versions
order: 11
summary: How these docs are built, versioned and released.
---

# Contributing and docs versions

BxCachy is written in BoxLang and compiled with MatchBox. The code is in `src/`, tests in `tests/`, and every command is described in the [command contract](../architecture/COMMAND-CONTRACT.md).

## These docs

The docs are built with [bxSites](https://bxsites.io) from `docs/` and `bxsites.yaml` and published to GitHub Pages at <https://bxcachy.boxlang.io> by `.github/workflows/docs.yml` on every push to `development`.

```bash
bx-module install bx-sites
boxlang bxSites serve           # build and serve with live reload
boxlang bxSites build           # build to site/
```

## Versions

`docs/` is the version being written, **{{ version }}**. When it ships:

```bash
boxlang bxSites version:new --name=1.0.x      # freeze a copy in docs/versions/1.0.x
```

Then set `versions.default: "1.0.x"` in `bxsites.yaml`: the release is served at the root and `docs/` becomes `/next/`. Every theme gets a version switcher. Patch releases edit `docs/versions/1.0.x/` in place; a new minor or major cuts a new version.

## Languages

English only for now. Add one with `boxlang bxSites i18n:new --code=es` and list it under `i18n.locales` in `bxsites.yaml`; `i18n:status` reports coverage.

## Releases

Pushes to `development` publish the `beta` channel; a `v*` tag publishes `stable`. See [Updates and channels](updates.md) and [Security](security.md).

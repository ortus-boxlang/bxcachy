---
title: MatchBox parity
order: 2
summary: Developer reference.
---

# MatchBox parity work: class entry, mappings, Application.bx

Source of truth: BoxLang JVM (`ortus-boxlang/boxlang`, read 2026-11-09 at b8ea0f0) and the BoxLang docs (CLI Scripting, Application.bx). MatchBox today (develop + our PRs) supports none of the three for scripts or native builds.

## 1. Class as entry point (`boxlang Task.bx a b`)

JVM: `BoxRuntime.executeTemplate` sends `.bx`/`.cfc` files to `executeClass`.

1. A request context is created and the Application listener is resolved (section 3).
2. The class is instantiated (its `init` is NOT special here; the constructor runs, pseudo-constructor included).
3. If the instance has a `main` member (`this` scope), run `listener.onRequestStart(templatePath)`. If it returns true, call `main( args )` where `args` is an **array of the raw CLI arguments after the file name**, in order (`["hola", "--many", "options=test"]`). `main` may be an instance or static method; `args = []` default is the convention.
4. Errors: abort -> `onAbort`; missing include -> `onMissingTemplate`; any other exception -> log, then `onError(exception, "")`, rethrown if `onError` is false. Always `onRequestEnd(templatePath)` and flush output.
5. No `main`: error `Class [X] does not have a main method to execute.` (non-zero exit).
6. A path without extension is presumed to be `<path>.bx`. `CLIGetArgs()` and `server.cli.parsed` work inside the class as in scripts.

## 2. Mappings

The only ways to declare them (owner decision, matches the JVM):

- `this.mappings` in `Application.bx`.
- `mappings` in `boxlang.json` (runtime config; the JVM default is `{ "/": "${user-dir}" }`).
- The `bx:application` component, which merges all of its attributes into the application settings (`name`, `mappings`, ...), then recomputes the request config.

Value forms: a string path, or a struct `{ path, external }` (`path` required, `external` default `true`; BoxLang 1.6+). Names are normalized to a leading and trailing slash (`models` and `/models/` are the same). Application mappings are merged over the global ones, application wins.

Class resolution order (`BoxResolver.findFromLocal`): 1) relative to the current template, 2) mappings (a mapping matches when the class path, as a slash path, starts with the mapping name; one candidate per valid extension, `.bx` before `.bxs` as configured), 3) custom component/class paths. Applies to `new`, `import`, `extends`, `implements` and `createObject("class", name)`.

## 3. Application.bx for scripts and classes

Discovery (`ApplicationService.loadDescriptorTemplate`): for an absolute script path, the descriptor is looked up in **the script's directory only**; for non-absolute (mapped) paths it walks up from the template's directory to its mapping root. Lookup order in a directory: class files `Application.bx` (valid class extensions, then `.cfc`), then templates `Application.<template extension>`. The class is instantiated **without calling `init()`**.

Settings read from `this`: `name`, `mappings`, `datasource`/`defaultDatasource`/`datasources`, `javaSettings`, `classPaths`/`componentPaths`, `customComponentPaths`, `caches`, `schedulers`, `watchers`, `timezone`, `locale`, `runtimeSettings`, security extension lists. A settings change recomputes the request config.

Lifecycle for a script or class run (no web scopes): application defined on first use -> `onApplicationStart()` once (only if `this.name` is set; false aborts) -> `onRequestStart(targetPage)` (false aborts) -> run the script (`template.invoke`; `onRequest` is not used for scripts) or `main(args)` -> `onRequestEnd()` -> flush. Errors go to `onError(exception, eventName)`; `abort` to `onAbort(targetPage)`. `onApplicationEnd(applicationScope)` on shutdown. Session hooks never fire in CLI.

## 4. Order of MatchBox work

1. Class entry with `main(args)` (interpreter and native).
2. Mappings: `boxlang.json`/`matchbox.toml` mappings plus `this.mappings` read from `Application.bx`; resolution wired into `new`, `import`, `extends`, `createObject`.
3. Application.bx for scripts and classes, with the lifecycle above.

Native builds resolve classes at compile time, so mapped directories must exist when `matchbox --target native` runs; the Application.bx settings that affect compilation (mappings) are read at build time, and the lifecycle runs inside the binary.

## MatchBox VM fixes (PRs 156 to 160, in the `bxcachy` branch)

Found while building the installer, fixed upstream, and BxRig no longer works around them: `break` in nested for-in loops (#156), a broken pipe on stdout (#157), calling a function stored in `variables` (#158), `switch` with `var` slots and the default jump (#159), and the panic message that was hidden (#160). Behaviour change in #159: a `var` declared in one `case` is not visible in another case.

---
name: bx-sites-actions
metadata:
  version: "1.0"
description: Operate and troubleshoot GitHub Actions workflows for ortus-boxlang/bx-sites. Use this when users ask about test failures, release runs, docs publish status, or rerunning/canceling workflows.
---

# bx-sites GitHub Actions Operations

Use this skill for CI and release operations in:
- Repository: `ortus-boxlang/bx-sites`
- Actions dashboard: `https://github.com/ortus-boxlang/bx-sites/actions`

## Workflow inventory

| Workflow | File | Trigger | Purpose |
|---|---|---|---|
| Daily Tests | `cron.yml` | cron `0 0 * * *` (UTC) | Calls `tests.yml` |
| Pull Requests | `pr.yml` | push on any branch except `main`/`master`/`development`/`releases/v*`; `pull_request` to `development` and `releases/v*`; both ignore `core/**`, `gradle-plugin/**`, `maven-plugin/**` | Calls `tests.yml`; cancels the older duplicate run per branch |
| Test Suites | `tests.yml` | `workflow_call` + `workflow_dispatch` only | The one real test workflow |
| Build Snapshot | `snapshot.yml` | push to `development`, dispatch | Runs `tests.yml`, then `release.yml` with `snapshot: true` |
| Release | `release.yml` | push to `main`/`master`, `workflow_call`, dispatch | Stable release (or snapshot when called with `snapshot: true`) |
| Docbox | `docbox.yml` | `workflow_call` + `workflow_dispatch` only | Generates API docs, uploads `./apidocs` to S3 via `./runDocs.sh` |
| Publish Docs | `pages.yml` | push to `development`/`main` (no `paths:` filter), dispatch | 10-theme matrix build, assemble, deploy to GitHub Pages |
| Gradle / Maven Plugin CI | `gradle-plugin-ci.yml`, `maven-plugin-ci.yml` | push to `development`/`main`/`master` and pull requests touching `core/**`, the plugin folder, or the workflow file | Job `Build & Test` on JDK 21 |
| Gradle / Maven Plugin Release | `gradle-plugin-release.yml`, `maven-plugin-release.yml` | tags `gradle-plugin-v*` / `maven-plugin-v*` | Test, then publish to the Gradle Plugin Portal / Maven Central |

The two plugin CI/release pairs are independent of the module's own
`tests.yml`/`release.yml` flow - a failing plugin job is usually a JDK 21 /
Gradle-and-Maven-only concern, not a bx-sites runtime regression. The Maven
jobs first run `./gradlew publishToMavenLocal` in `core/`, so a Maven failure
can originate in `core/`.

## Where failures show up

**`tests.yml`** (reached via `cron.yml`, `pr.yml`, `snapshot.yml`):
- Matrix: `ubuntu-latest` (job `Tests bx-sites`) and `windows-latest` (job
  `Tests bx-sites (windows-latest)`). Both are required; a red Windows job
  fails the run. It covers path handling (backslashes, drive letters).
- CI installs `bx-esapi bx-yaml bx-toml bx-markdown bx-image bx-docbox` with
  `setup-boxlang@1.6.0` (`with-commandbox`). A missing module shows up as a
  spec or build error, not a setup error.
- Step **Run Tests**: TestBox does not return a failing exit code, so this
  step sums `tests`/`failures`/`errors` across `tests/results/*.xml` and fails
  on any failure or error. 0 tests or no XML at all is treated as a crash
  (likely a compile or bootstrap error earlier in the log). Each failing spec
  is printed as `FAILURE: <class> > <spec>` or `ERROR: <class> > <spec>` in
  that step's log - start there.
- Step **Smoke Test - Real CLI Build** (pwsh): `bxSites new`, `build`,
  `page:rename`, `build`, asserting `site/` outputs and the rewritten link. It
  fails on any non-zero CLI exit. A failure here with green specs means a
  real-CLI or path bug the TestBox fakes missed.
- Artifacts `tests-<os>` hold the JUnit XML; job `Publish Test Results`
  publishes them.

**`release.yml`**: job `build` ("Build & Publish Release") runs
`setup-boxlang@1.6.0`, finalizes the changelog and `docs/releases/` page
(non-snapshot only), builds with `Build.bx`, tags, uploads to S3, publishes to
ForgeBox, and creates the GitHub release. Job `prep_next_release` is skipped
on `development`; otherwise it checks out `development`, runs `box bump
--minor --!TagVersion` (module `bx-cli`) and commits "Version bump". A
snapshot failure is usually in the S3 or ForgeBox step, not the tests, since
`snapshot.yml` already ran them.

**`docbox.yml`**: `setup-boxlang@1.6.0` with `bx-docbox`; failures are in
"Generate Documentation" (`./runDocs.sh`) or the S3 upload.

**`pages.yml`** ("Publish Docs"): `main` deploys the site root, `development`
deploys only `/next/` once `main` exists (whole site before then). Key log
steps, in order: "Build the site" (per theme), "Verify the build actually
produced output" (fails if `site/` is empty), "Detect whether main exists
yet" (step `detect-main`, a live `git ls-remote`), "Deploy the pruned site/
tree to GitHub Pages" (`peaceiris/actions-gh-pages@v4`, `keep_files: true`).
One red matrix leg (`Build [<theme>] (<branch>)`) blocks `assemble-and-deploy`
for all themes. Runs are grouped per branch with `cancel-in-progress: false`.
If the live site is stale, check the run for that branch before the other.

**Plugin workflows**: JDK 21 (temurin). CI runs `./gradlew check` in `core/`
and the plugin (Maven: `mvn --batch-mode verify`). Releases are triggered by
pushing a `gradle-plugin-v<version>` / `maven-plugin-v<version>` tag; the
tag suffix becomes the published version.

**Versions**: BoxLang 1.18.0 is the module minimum; the bx-sites CLI exits
non-zero on failure, so a red step that runs `boxlang bxSites ...` is a real
failure, not a masked one.

## Required troubleshooting flow

When users mention CI/build/test/workflow failures, always do this:

1. List recent runs for the target workflow or repository.
2. Inspect failed jobs and fetch logs.
3. Identify the first actionable root cause.
4. Recommend minimal remediation steps.
5. If requested, trigger rerun or cancel stuck runs.

## Suggested GitHub tool operations

- List workflows: `actions_list(method=list_workflows)`
- List runs: `actions_list(method=list_workflow_runs, resource_id=<workflow id or file>)`
- List jobs: `actions_list(method=list_workflow_jobs, resource_id=<run id>)`
- Read logs: `get_job_logs(job_id=<job id>, return_content=true)`
- Rerun run: `actions_run_trigger(method=rerun_workflow_run, run_id=<run id>)`
- Rerun failed jobs: `actions_run_trigger(method=rerun_failed_jobs, run_id=<run id>)`
- Cancel run: `actions_run_trigger(method=cancel_workflow_run, run_id=<run id>)`

## Output expectations

For each investigation, report:
- Workflow/run/job identifiers
- Failing step name
- Direct error excerpt from logs
- Root cause summary
- Minimal fix or rerun recommendation

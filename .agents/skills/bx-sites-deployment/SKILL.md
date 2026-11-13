---
name: bx-sites-deployment
metadata:
  version: "1.0"
description: Deploy, package, or publish a built bx-sites (ortus-boxlang/bx-sites) site - deployments/ entries (.yaml/.yml/.toml/.json) for S3-compatible, Azure, GCS, Firebase, FTP/SFTP, rsync, Cloudflare Pages, local, and GitHub Pages targets, secrets-in-env-vars conventions, bxSites package, bxSites publish to bxSites Cloud (the cloud/siteId/apiUrl config key and BXSITES_CLOUD_TOKEN), the GitHub Actions Pages publishing workflow (main at the site root, development at /next/), and restricting who can reach a deployed site. Use this whenever a user wants to ship a built bx-sites site somewhere, publish it to bxSites Cloud, set up CI/CD publishing, or gate access to a deployed site.
---

# BxSites Deployment Reference

`site/` is a plain static site - host it anywhere that serves static files.
`bxSites deploy` ships it there directly. `deploy` always builds first (there
is no skip-build path), so you don't need a separate `build` - see
`bx-sites-build`.

## The `deploy` command - three invocation shapes

```bash
bxSites deploy --entry=production [--verbose]                    # 1. named deployments/<name>.yaml
bxSites deploy --target=local|github-pages [flags] [--verbose]   # 2. flag-only, no deployments/ file
bxSites deploy [--verbose]                                       # 3. every deployments/ entry
```

1. **`--entry=<name>`** dispatches to whatever `deployments/<name>.<ext>`
   declares - every target except `local`/`github-pages` needs this (more
   config than a couple of flags can carry).
2. **`--target=<name>` with its own flags** - shorthand for the two simplest
   targets only, no `deployments/` folder at all: `local` (`--destination=<path>`)
   and `github-pages` (`[--branch] [--remote] [--message]`, same defaults as
   `gh-deploy`).
3. **Neither flag** - every `deployments/` entry deployed in turn, off
   **one shared build** (not rebuilt per target). One target failing doesn't
   stop the rest; the command exits non-zero only if at least one failed,
   and the summary reports the count (`Deployed to 2/3 target(s) (1 failed)`).
   With no entries (and no `--entry`/`--target`) it throws
   `BxSites.NoDeploymentsFound`.

`--verbose` prints a progress line as the build and each target start/finish,
instead of just the final summary.

### `deployments/` entries

One file per target, in `.yaml`, `.yml`, `.toml` or `.json` (the same formats
as the site config; every field works the same in any of them). The entry
name is the file name up to the first `.` (`production.yaml` is
`production`); dotfiles are ignored. The same name in two formats
(`production.yaml` + `production.json`) is a `Duplicate deploy entry name`
error. Each entry needs a `target`, one of: `local`, `github-pages`, `s3`,
`ftp`, `sftp`, `rsync`, `azure`, `gcs`, `firebase`,
`cloudflare-pages`. Any error in `deployments/` (unknown target, missing
required field, duplicate name, unreadable file) fails the run **before**
building.

File-path fields (`gcs`/`firebase` `serviceAccountKeyPath`, `sftp` `key`,
`rsync` `identityFile`, `local` `destination`, and `package --output`) may be
absolute, start with `~/`, or be relative to the **project root**.

## Secrets

**Always from an environment variable, never a literal value** in
`deployments/` files. Every field ending `EnvVar` names the *env var*
holding the real secret, resolved live at deploy time - so the entry file
itself is always safe to commit. A field that's a *path* to a credential
file already managed separately (an SSH key, a downloaded GCP service-
account JSON) is the one exception - a plain field, since the file itself
(not its path) is what's kept out of version control. Locally, those env
vars can come from a `.env` file (BoxLang loads it automatically); in CI,
set them as real runner secrets.

## Targets

### `local`

No `deployments/` entry needed - the only target that doesn't.

```bash
bxSites deploy --target=local --destination=/path/to/somewhere
```

### `github-pages`

The same push `gh-deploy` does, reachable from the unified command too - no
`deployments/` entry needed either.

```bash
bxSites deploy --target=github-pages [--branch=gh-pages] [--remote=origin] [--message="..."]
```

### `s3`

Real AWS S3, or any S3-compatible service. Set `endpoint` for non-AWS, and
`forcePathStyle: true` for most non-AWS providers.

```yaml title="deployments/production.yaml"
target: s3
bucket: my-docs-site
region: us-east-1        # default
prefix: ""
accessKeyIdEnvVar: AWS_ACCESS_KEY_ID
secretAccessKeyEnvVar: AWS_SECRET_ACCESS_KEY
```

```json title="deployments/spaces.json (DigitalOcean Spaces)"
{
  "target": "s3",
  "bucket": "my-docs-site",
  "endpoint": "https://nyc3.digitaloceanspaces.com",
  "forcePathStyle": true,
  "accessKeyIdEnvVar": "SPACES_KEY",
  "secretAccessKeyEnvVar": "SPACES_SECRET"
}
```

Same shape (custom `endpoint` + `forcePathStyle: true`) also covers
Cloudflare R2 (`https://<accountid>.r2.cloudflarestorage.com`), Backblaze
B2, and MinIO/Wasabi. `region` defaults to `us-east-1`. `prefix` is
normalized (no leading `/`, exactly one trailing `/`). Optional `acl` (e.g.
`"public-read"`) is sent as the `x-amz-acl` header when present. Request
signing and key URL-encoding are consistent in both addressing styles, so
keys with spaces or non-ASCII characters upload correctly.

S3, Azure, GCS and Cloudflare Pages share one `Content-Type` map
(`models/deploy/ContentTypes.bx`): `.md` and `.txt` get `charset=utf-8`,
unknown extensions get `application/octet-stream`.

### `azure`

```yaml title="deployments/production.yaml"
target: azure
account: mystorageaccount
container: site
accountKeyEnvVar: AZURE_STORAGE_KEY
```

Authenticate with exactly one of a SAS token, an account key, or a full
connection string - `sasTokenEnvVar`, `connectionStringEnvVar`, or
`accountKeyEnvVar` (in that precedence order if more than one is somehow
set). Optional `prefix` prefixes every uploaded blob name (e.g. `"docs/"`).

### `gcs`

```yaml title="deployments/production.yaml"
target: gcs
bucket: my-docs-site
serviceAccountKeyPath: ~/keys/service-account.json
```

Downloaded service-account JSON key (Google Cloud Console → IAM & Admin →
Service Accounts → Keys). Optional `prefix` prefixes every object name.

### `firebase`

```yaml title="deployments/production.yaml"
target: firebase
siteId: my-firebase-site
serviceAccountKeyPath: ~/keys/service-account.json
```

Optional `projectId` (defaults to `siteId`).

### `ftp` / `sftp`

```yaml title="deployments/production.yaml"
target: sftp
host: example.com
username: deploy
remotePath: /var/www/html
key: ~/.ssh/id_rsa
```

Both need the **bx-ftp** module; `bxSites doctor` checks for it only when a
`deployments/` entry uses `ftp` or `sftp`. SFTP accepts a password
(`passwordEnvVar`) or an SSH key (`key`, a **path** to the private key file,
plus optional `passphraseEnvVar` for that key); FTP requires
`passwordEnvVar`. Both preserve the site's folder structure. Other optional
fields: `port` (FTP `21`, SFTP `22`), `passive` (FTP, `true`),
`proxyServer`, `timeout` (seconds, `30`), and SFTP's `fingerprint`.

### `rsync`

```yaml title="deployments/production.yaml"
target: rsync
host: example.com
username: deploy
remotePath: /var/www/html
identityFile: ~/.ssh/id_rsa
```

Real `rsync` binary over SSH - only transfers what changed, faster than
FTP/SFTP for a full rebuild. Requires `rsync` and `ssh` on the machine
running `bxSites`. Optional fields: `port` (`22`), `identityFile` (SSH
private key, passed as `-i`), `sshOptions` (raw extra string appended to the
`ssh` sub-command), and `deleteExtraneous` (boolean, default `false`; `true`
adds `--delete`, removing remote files no longer in `site/`). The ssh
sub-command always includes `-o StrictHostKeyChecking=accept-new`, so the
first contact with a new host is auto-trusted and later ones are verified. A
`remotePath` of `/`, `~`, `.` (or empty) is refused with `InvalidDeployConfig`
- point it at the site's own folder.

### `cloudflare-pages`

```yaml title="deployments/production.yaml"
target: cloudflare-pages
accountId: your-account-id
projectName: my-project
apiTokenEnvVar: CLOUDFLARE_API_TOKEN
```

Cloudflare has no documented REST API for direct-upload deploys (only
`wrangler`) - this target reverse-engineers Wrangler's own upload flow and
needs a BLAKE3 hash implementation most default JVMs don't ship. Treat as
the roughest-edged target; verify a real deploy before relying on it.

## `publish` - bxSites Cloud

[bxSites Cloud](https://bxsites.io) is a hosting SaaS built specifically for
bxSites sites - `bxSites publish` builds and ships there directly over its
own publish API, distinct from `deploy`'s pluggable targets above (which all
ship to infrastructure you own):

```bash
export BXSITES_CLOUD_TOKEN="cb_..."
bxSites publish
```

```yaml title="bxsites.yaml"
cloud:
  siteId: "3f2b1c9a-....-....-............"   # the target site's UUID
  apiUrl: "https://cloud.bxsites.app"          # or a self-hosted instance
```

**The API token never goes in `bxsites.yaml`** - `publish` reads it from
`BXSITES_CLOUD_TOKEN`, or an explicit `--token=cb_...` flag (wins when both
are set), so this file always stays safe to commit. On success it prints
the site's live URL; it fails with a specific, actionable error rather than
a stack trace for: no/incomplete `cloud` block, no token available,
401/403 (bad/unauthorized token), 404 (bad `cloud.siteId`), or anything
else (400/413/500/network failure, with the actual status/body included).
Like every verb, it exits non-zero on failure, so CI can rely on the step's
exit status (still worth confirming `site/` has content).

bxSites Cloud is also what actually serves the AI-facing features described
in `bx-sites-ai-features` (a published site's MCP server) and the
`::: contact-form :::` block described in `bx-sites-content-blocks`, plus
`cloud.comments`/`::: comments` - all render/build with the open-source
module alone, but need a paid Cloud plan to actually work once published.

## `package` - a plain archive instead

```bash
bxSites package
bxSites package --output=dist/my-site.zip
```

Builds, then zips `site/`'s own contents (not a wrapping `site/` folder)
into one file - for attaching to a GitHub release, a host that only accepts
a zip upload, or any target the pluggable list above doesn't reach.
`--output` defaults to `<projectRoot>/site.zip` (absolute, `~/`, or
project-root-relative); parent directories are created automatically.

## GitHub Actions: publishing to GitHub Pages

bx-sites' own `.github/workflows/pages.yml` ("Publish Docs") is the pattern
the project's docs use. It runs on push to `development` and `main` (no
`paths:` filter, so every push rebuilds) plus `workflow_dispatch`, and the
two branches own different parts of one `gh-pages` site:

- `main` deploys the **site root** (whatever `versions.default` points at).
- `development` deploys **only `/next/`** (the plain `docs/` tree) once
  `main` exists, so it can't clobber the root. Before `main` exists it
  deploys the whole site, so the root is never left unpublished. The check
  is a live `git ls-remote` (step id `detect-main`), so the switch happens
  on its own when `main` is cut.
- There is no `destination_dir`, no `/development/` path and no per-branch
  `baseURL` rewrite; `baseURL` comes from `bxsites.yaml` as committed.

Jobs:

1. `build` - a matrix over the 10 built-in themes. Each job checks out,
   runs `ortus-boxlang/setup-boxlang@1.6.0` (`with-commandbox: true`,
   modules `bx-esapi bx-yaml bx-toml bx-markdown bx-image`), links the repo
   into `BOXLANG_HOME/modules`, rewrites `theme.name` and `baseURL`
   (`.../theme/<name>/`) for every non-`bootstrap` theme, runs
   `boxlang bxSites build`, checks `site/` is non-empty, and uploads
   artifact `site-<theme>`.
2. `assemble-and-deploy` - downloads all artifacts, puts `bootstrap` at the
   root and the others under `theme/<name>/`, prunes `next/` on `main` or
   keeps only `next/` on `development`, then publishes with
   `peaceiris/actions-gh-pages@v4` using `keep_files: true` (so a prune
   leaves the other branch's files alone) and `cname` (writes `CNAME` at the
   `gh-pages` root).

`concurrency` is `pages-${{ github.ref_name }}` with `cancel-in-progress:
false`, so `main` and `development` runs never queue behind each other.

For your own project, copy it and trim: a single theme needs no matrix or
assemble step, and a project without a `development`/`main` split just
builds and publishes `site/` from one branch.

**One-time setup** (after the workflow has run at least once, since the
first run creates the `gh-pages` branch): Settings → Pages → Build and
deployment → Source: "Deploy from a branch" → Branch: `gh-pages` / `(root)`.

**Project Pages sub-path** - `https://<user>.github.io/<repo>/` (as opposed
to a `<user>.github.io` user site) needs `baseURL` set to that full URL so
every internal link/asset/nav entry gets the `/<repo>/` prefix and a real
`sitemap.xml` is generated (see `bx-sites-configuration`). A user site or a
custom domain mapped to the root can leave `baseURL` at its default (`/`).

## Restricting who can reach a deployed site

No built-in access control - a plain static `site/` has no concept of "who's
asking." `robots: false` tells well-behaved crawlers not to index it, but
it's a polite request, not a lock - the URL still works for anyone who has
it. Real access restriction has to happen in front of the static files, at
whichever host serves them:

- **Cloudflare Pages/Access** - a Cloudflare Access policy (email allowlist,
  SSO, one-time PIN), no application code.
- **A tiny reverse-proxy** (any host) - HTTP Basic Auth in front of the
  static files - keeps out search engines and casual visitors, not real
  per-user identity.

None of these are bx-sites features - they're host-level settings.

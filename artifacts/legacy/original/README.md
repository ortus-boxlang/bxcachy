# Original BxCachy v0.10.0 implementation

This directory is reserved for the **extracted original source files**, preserving the paths from the historical `BxCachy-v0.10.0-integration-hardening.zip` archive.

The source tree must be committed as individual files under:

```
artifacts/legacy/original/BxCachy/
  bin/
  catalog/
  config/
  icons/
  menu/
  tests/
  ...
```

Do **not** commit the ZIP. Keep historical Python files unmodified and isolated from the native BoxLang/MatchBox runtime.

Expected source inventory: 104 regular files (115 ZIP entries including 11 directories); 44 executable entrypoints under `bin/` and 20 Python test files.

Source archive SHA-256: `94e1722eb7d5e915a357a98f02fbbf3f7d2ae5dce01cdbdd1b20b1072a4e5819`.

To import the original files from the local archive, run from the repository root:

```bash
sha256sum BxCachy-v0.10.0-integration-hardening.zip
mkdir -p artifacts/legacy/original
unzip -q BxCachy-v0.10.0-integration-hardening.zip -d artifacts/legacy/original
git add artifacts/legacy/original
git commit -m "archive: preserve extracted original BxCachy v0.10.0 source"
git push origin development
```

**Import status:** pending; this README is a manifest, not evidence that the source tree was committed. Confirm the 104 extracted files appear in GitHub before marking archival complete.

# Historical v0.10.0 source archive

Original archive: `BxCachy-v0.10.0-integration-hardening.zip`

- SHA-256: `94e1722eb7d5e915a357a98f02fbbf3f7d2ae5dce01cdbdd1b20b1072a4e5819`
- Size: 151,644 bytes
- ZIP entries: 115, including 11 directory entries
- Regular files: 104
- `BxCachy/bin/` executable entrypoints: 44
- `BxCachy/tests/` Python test files: 20

The historical ZIP was verified in the working container. **The ZIP itself is not yet committed to GitHub**: the available repository content connector supports UTF-8 text files, not binary ZIP uploads, and this runtime cannot reach the Git remote. This manifest intentionally does not pretend that the binary is stored here.

When Git transport or a binary-capable release-asset uploader is available, add the original unmodified ZIP at `artifacts/legacy/BxCachy-v0.10.0-integration-hardening.zip`, verify the SHA-256 and file counts, and retain it as historical source only. Do not add Python as a native runtime dependency.

Migration inventory and command mapping: [plan.md](../../plan.md#17-audited-historical-v0100-source-archive--recovered-2026-11-08).

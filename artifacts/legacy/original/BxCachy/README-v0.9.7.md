# BxCachy 0.9.7 — vector database recipes (incremental build)

Adds `bxcachy vector` to the command dispatcher, with a safe, localhost-only, persistent Podman recipe interface.

- `bxcachy vector doctor`: inspect dependencies
- `bxcachy vector list`: list BxCachy-managed vector containers
- `bxcachy vector plan qdrant`: show configuration without side effects
- `bxcachy vector start qdrant --yes`: explicitly create the container
- `bxcachy vector stop qdrant`; `logs`, `status`, `remove --yes`
- Engines: Qdrant, Chroma, Weaviate, PostgreSQL/pgvector; Milvus is catalogued but requires an official multi-service deployment, so intentionally refuses to start an incomplete single-container setup.

**Security and maturity:** No automatic database services start on installation. Exposed ports bind to 127.0.0.1. Weaviate is configured with anonymous access for local development only. Image tags are pinned examples, not security-maintained production versions. PostgreSQL password stored in a user-local file with mode 0600. Do not expose these ports externally. No live Podman image pulls or GUI integration tests have been performed.

**Still pending:** Mac-style Quick Look, global dictation, richer database center, verified Milvus compose deployment, cloud OAuth tests, Hyprland compatibility tests, integration test on CachyOS.

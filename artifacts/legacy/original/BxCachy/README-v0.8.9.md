# BxCachy v0.8.9 — Opinionated curated catalog + local databases

- New requested defaults: Zap WhatsApp, GrokBot, Claude Desktop, ChatGPT Desktop, OpenCode, Pi, Herder, tmog, Notion Desktop; existing VS Code, Slack and Zoom retained.
- Unverified/manual sources **do not silently count as installed**; they fail visibly until installer mapping is verified. Some requested names need product identification.
- Full offline app picker: `catalog/app-picker.html` with descriptions and JSON selection export. The export is for review, not yet a profile-import action.
- Local rootless Podman DB manager: `bxcachy db plan postgres`, `bxcachy db start postgres --yes`, `bxcachy db list`, `bxcachy db logs postgres`, `bxcachy db stop postgres`, `bxcachy db remove postgres --yes`.
- Engines: PostgreSQL, MariaDB, MySQL, Redis. Localhost-only ports, persistent data, random credentials stored mode 0600. Data is never automatically deleted.
- No CachyOS, KDE, Hyprland, or Noctalia changes.
- Security note: database credentials are stored in local user files; inspect permissions and backup policies. Redis defaults to localhost-only and no password; do not expose its port.
- Live CachyOS/Podman and upstream package verification remain pending.

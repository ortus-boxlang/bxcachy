# BxCachy v0.8.8 — Three-tier app installation

1. **Base**: 29 selected application catalog entries, automatically attempted during first-run install. Existing system base packages remain unchanged.
2. **Curated**: All other entries in `catalog/apps.json`, searchable and individually installable via `bxcachy app-manager gui`.
3. **Full Arch/AUR**: `bxcachy app-manager system-search --query NAME` or add `--aur` for yay. These search commands do not install packages.

Commands:
```bash
./bin/bxcachy app-manager defaults
./bin/bxcachy app-manager list --tier curated
./bin/bxcachy app-manager install-defaults   # preview
./bin/bxcachy first-run plan
./bin/bxcachy first-run install --yes
./bin/bxcachy app-manager system-search --query firefox
./bin/bxcachy app-manager system-search --query firefox --aur
```

**Caveats**: Some curated entries are advisory or have unverified package mappings; these are not automatically installed. Web defaults create launchers using an available browser. Live CachyOS testing remains outstanding. No desktop environment is replaced.

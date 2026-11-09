# Phosphor Icons

BxCachy uses the official Phosphor Regular SVG collection. To avoid bundling inaccurate or unofficial artwork, the pack downloads only the named SVGs from `phosphor-icons/core` when you explicitly run `bxcachy icons sync`. The SVGs are cached in `~/.local/share/bxcachy/icons/phosphor/regular/`.

The app remains usable without downloading icons, using freedesktop icon-theme names as fallbacks. No CDN is required at runtime after sync. Original artwork: https://github.com/phosphor-icons/core (MIT license). Product branding uses freedesktop fallback icons until separately provided official logos are installed.

# BxCachy v0.9.4 — VPN and remote desktop

- NordVPN optional: AUR `nordvpn-bin` + `nordvpn-gui` (ArchWiki-documented). GUI and daemon must be validated on CachyOS.
- NordLayer optional: AUR `nordlayer` is unofficial; inspect PKGBUILD before installing.
- Remote defaults: Remmina for RDP (Windows) and VNC (Mac Screen Sharing), RustDesk for agent-based access. KRDC is a KDE alternative.
- `bxcachy network plan nordvpn`; `bxcachy network install nordvpn --yes`; `bxcachy network open nordvpn`.
- `bxcachy network plan nordlayer`; `bxcachy network install nordlayer --yes`.
- `bxcachy network open remote` opens an installed client.
- No VPN connects automatically; do not expose RDP or VNC ports to the public internet.
- Corrected Canva URL in catalog and default profile (replacing Canvas LMS).
- Live Hyprland/Wayland GUI testing and AUR package verification pending.

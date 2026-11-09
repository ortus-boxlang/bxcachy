# BxCachy v0.9.3 — Web apps, remote desktop, VPN

Default web shortcuts: Squoosh, Canvas LMS, Gamma. Canvas was interpreted as Canvas LMS; change to Canva if that was intended.

Default remote desktop clients: Remmina, KRDC, FreeRDP (RDP/VNC), RustDesk (AUR mapping not verified). macOS Screen Sharing must be enabled on the remote Mac; Windows Remote Desktop requires an RDP-capable Windows edition and appropriate permissions. RustDesk requires setup on both ends.

Tailscale is a default pacman package. Installation does not automatically log in or join a tailnet. On CachyOS: `sudo systemctl enable --now tailscaled` and `sudo tailscale up` after reviewing the network configuration.

NordLayer (manual source) and NordVPN (unverified AUR candidate) remain optional.

Use `./bin/bxcachy app-manager defaults` and `./bin/bxcachy app-manager install-defaults` to preview. `--yes` installs; check the AUR source first. Existing KDE, Hyprland and Noctalia configurations are not modified.

# BxCachy v0.9.8 — Dictation, Quick Look, Cloud Center

## Implemented
- `bxcachy dictation doctor|toggle|status|shortcut-help`: local whisper.cpp transcription with PipeWire recording and Wayland `wtype` insertion. No external transcription service. Requires local ggml Whisper model, `whisper-cli`, `pw-record`, `wtype`. Opt-in global shortcut only; the desktop binding is NOT automatically changed. `Super+D` is an example, not installed. Existing shortcuts remain intact. The process uses SIGUSR1 on second toggle.
- `bxcachy quicklook FILE`: read-only Qt preview for images, text/code, and PDFs when QtPdf available; Escape/Space closes preview. Other formats need external viewers. Dolphin context-menu service-menu example included in `integrations/dolphin`; requires installation and compatibility verification on Plasma 6. Dolphin does NOT automatically bind Space to preview.
- `bxcachy cloud-center`: Tkinter GUI for configured rclone remotes, interactive rclone configuration via Ghostty, mount/unmount and opening mounted folders in Dolphin. Uses existing `bxcachy cloud` backend. No credentials stored by BxCachy. Requires python-tk, rclone and fuse3.
- Preserved CLI and existing menu integrations. Unified Quasar/Tauri Control Center remains deferred.

## Setup and validation limitations
These are initial implementations, NOT verified on CachyOS/Hyprland. Dictation depends on working input permissions, Wayland focused window support, whisper.cpp model and CLI version. `wtype` works only with compositors supporting virtual keyboard protocol; fallback needs design/testing. The Tkinter cloud GUI is functional but not the future polished control center. `rclone mount` is not offline synchronization; official Dropbox and Insync remain optional. Dolphin service-menu desktop file requires correct installed `bxcachy-quicklook` PATH and current KDE service-menu format; no system file manager config modified.

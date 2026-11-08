#!/usr/bin/env bash
set -euo pipefail
usage() { echo 'Usage: package-manager.sh plan|doctor|install [--yes] | optional-list | optional-install NAME... --yes' >&2; exit 2; }
command -v pacman >/dev/null || { echo 'Requires Arch/CachyOS pacman' >&2; exit 2; }
[[ $# -ge 1 ]] || usage
action=$1; shift
base=(localsend mpv pacseek)
declare -A optional=([obs]=obs-studio [kdenlive]=kdenlive [pinta]=pinta [chromium]=chromium [obsidian]=obsidian [libreoffice]=libreoffice-fresh)
packages=(); yes_flag=0
case "$action" in
 optional-list) [[ $# -eq 0 ]] || usage; for name in "${!optional[@]}"; do printf '%s: %s (optional)\n' "$name" "${optional[$name]}"; done | sort; exit 0 ;;
 plan|doctor|install) packages=("${base[@]}"); for arg in "$@"; do [[ $arg == --yes && $action == install ]] || usage; yes_flag=1; done ;;
 optional-install) for arg in "$@"; do if [[ $arg == --yes ]]; then yes_flag=1; elif [[ -n ${optional[$arg]+set} ]]; then packages+=("${optional[$arg]}"); else usage; fi; done; [[ ${#packages[@]} -gt 0 ]] || usage ;;
 *) usage ;;
esac
missing=()
for pkg in "${packages[@]}"; do
 if pacman -Qq "$pkg" >/dev/null 2>&1; then echo "$pkg: installed"; else echo "$pkg: missing"; missing+=("$pkg"); fi
done
[[ $action == plan || $action == doctor ]] && exit 0
[[ $yes_flag -eq 1 ]] || { echo 'Installation requires --yes' >&2; exit 2; }
available=(); unavailable=()
for pkg in "${missing[@]}"; do if pacman -Si "$pkg" >/dev/null 2>&1; then available+=("$pkg"); else unavailable+=("$pkg"); fi; done
if [[ ${#unavailable[@]} -gt 0 ]]; then
 printf 'Unavailable in pacman repositories: %s\n' "${unavailable[*]}" >&2
 [[ $action == optional-install ]] && exit 3
fi
if [[ ${#available[@]} -gt 0 ]]; then sudo pacman -S --needed "${available[@]}"; fi

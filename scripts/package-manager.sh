#!/usr/bin/env bash
set -euo pipefail
usage() { echo 'Usage: package-manager.sh plan|doctor|install [--yes] | optional-list | optional-install NAME... --yes | profile-list | profile-install NAME --yes' >&2; exit 2; }
command -v pacman >/dev/null || { echo 'Requires Arch/CachyOS pacman' >&2; exit 2; }
[[ $# -ge 1 ]] || usage
action=$1; shift
base=(localsend mpv pacseek)
declare -A optional=([obs]=obs-studio [kdenlive]=kdenlive [pinta]=pinta [chromium]=chromium [obsidian]=obsidian [libreoffice]=libreoffice-fresh)
declare -A profiles=([core]='git curl jq unzip' [jvm]='jdk21-openjdk maven gradle' [containers]='podman buildah skopeo' [terminal]='btop neovim lazygit yazi')
packages=(); yes_flag=0
case "$action" in
 profile-list) [[ $# -eq 0 ]] || usage; for name in "${!profiles[@]}"; do printf '%s: %s\n' "$name" "${profiles[$name]}"; done | sort; exit 0 ;;
 profile-install) [[ $# -eq 2 && "$2" == --yes && -n ${profiles[$1]+set} ]] || usage; read -r -a packages <<< "${profiles[$1]}"; yes_flag=1 ;;
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
pacman_packages=(); aur_packages=(); unavailable=()
for pkg in "${missing[@]}"; do
  if pacman -Si "$pkg" >/dev/null 2>&1; then
    pacman_packages+=("$pkg")
  elif command -v yay >/dev/null 2>&1 && yay -Si "$pkg" >/dev/null 2>&1; then
    aur_packages+=("$pkg")
  else
    unavailable+=("$pkg")
  fi
done
if [[ ${#unavailable[@]} -gt 0 ]]; then
  printf 'Unavailable in pacman and yay repositories: %s\\n' "${unavailable[*]}" >&2
  echo 'No packages installed: resolve missing repository packages first.' >&2
  exit 3
fi
if [[ ${#pacman_packages[@]} -gt 0 ]]; then
  sudo pacman -S --needed "${pacman_packages[@]}"
fi
if [[ ${#aur_packages[@]} -gt 0 ]]; then
  yay -S --needed "${aur_packages[@]}"
fi

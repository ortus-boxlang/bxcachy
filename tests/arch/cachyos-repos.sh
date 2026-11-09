#!/usr/bin/env bash
# Enables the CachyOS package sources on a plain Arch image, following the manual
# method in the CachyOS wiki. Runs as root at image build time.
# Repos added after the stock Arch repos: cachyos (generic), v3, v4 and multilib. Output: /etc/pacman.conf, plus the list of repos on stdout.
set -euo pipefail
base=https://mirror.cachyos.org/repo/x86_64/cachyos
key=F3B607488DB35A47
pacman-key --init
# HKP (port 11371) is often blocked; fetch the same key over HTTPS, then require the
# imported key ID to match the one published by CachyOS before trusting it.
curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&options=mr&search=0x$key" -o /tmp/cachyos.asc
gpg --show-keys --with-colons /tmp/cachyos.asc | awk -F: '/^fpr/{print $10}' | grep -q "$key\$" \
  || { echo "CachyOS key $key not found in downloaded key" >&2; exit 1; }
pacman-key --add /tmp/cachyos.asc
rm -f /tmp/cachyos.asc
pacman-key --lsign-key "$key"
listing="$(curl -fsSL "$base/")"
pick() { grep -o "href=\"$1-[0-9][^\"]*\\.pkg\\.tar\\.zst\"" <<<"$listing" | sed 's/href="//;s/"$//' | sort -V | tail -1; }
pkgs=()
for p in cachyos-keyring cachyos-mirrorlist cachyos-v3-mirrorlist cachyos-v4-mirrorlist; do
  f="$(pick "$p")"; [[ -n "$f" ]] || { echo "cannot find $p" >&2; exit 1; }
  curl -fsSL -o "/tmp/$f" "$base/$f"; pkgs+=("/tmp/$f")
done
pacman -U --noconfirm "${pkgs[@]}"
rm -f /tmp/cachyos-*.pkg.tar.zst

cp /etc/pacman.conf /etc/pacman.conf.arch
# Explicit architecture list (the `auto` keyword is not available in every pacman).
sed -i 's/^Architecture = .*/Architecture = x86_64 x86_64_v3 x86_64_v4/' /etc/pacman.conf
# CachyOS repos go AFTER the stock repos on purpose: CachyOS-only packages (for example
# noctalia-shell) resolve, while core libraries stay the generic x86_64 builds, so the
# result does not depend on which CPU the CI runner happens to have. A real CachyOS
# machine puts the v3/v4 repos first; that difference is covered by the hardware test.
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
  printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf
fi
cat >> /etc/pacman.conf <<'CONF'

[cachyos-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
[cachyos-core-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
[cachyos-extra-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
[cachyos-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist
[cachyos-core-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist
[cachyos-extra-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist
[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
CONF
pacman -Syy --noconfirm
echo "== repos in use =="; pacman-conf --repo-list

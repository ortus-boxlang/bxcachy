#!/usr/bin/env bash
# Makes the BxRig release signing key pair (Ed25519, OpenSSL). Run once, on your machine:
#   scripts/gen-signing-key.sh [OUTDIR]
# Writes OUTDIR/bxrig-release.key (PRIVATE: store it as the GitHub secret BXRIG_SIGNING_KEY, then delete the file) and
# keys/release.pub (public: commit it). CI signs version-latest.properties and install.sh with the secret; the installer and
# `bxrig update` verify with the public key.
set -euo pipefail
out="${1:-$HOME}"
root="$(cd "$(dirname "$0")/.." && pwd)"
command -v openssl >/dev/null || { echo "openssl is required" >&2; exit 1; }
[[ ! -e "$out/bxrig-release.key" ]] || { echo "$out/bxrig-release.key exists; not overwriting" >&2; exit 1; }
umask 077
openssl genpkey -algorithm ed25519 -out "$out/bxrig-release.key"
mkdir -p "$root/keys"
openssl pkey -in "$out/bxrig-release.key" -pubout -out "$root/keys/release.pub"
echo "Private key: $out/bxrig-release.key"
echo "  -> add it as the repository secret BXRIG_SIGNING_KEY (paste the whole file), then delete it or keep it offline."
echo "Public key:  $root/keys/release.pub"
echo "  -> commit it, then run bootstrap/gen-releasekey.sh to embed it in the binary."

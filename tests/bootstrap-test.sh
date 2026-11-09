#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/pacman" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  -Qq) [[ "$2" == git ]] ;;
  *) echo "unexpected pacman invocation" >&2; exit 9 ;;
esac
MOCK
cat > "$tmp/sudo" <<'MOCK'
#!/usr/bin/env bash
echo "unexpected sudo invocation" >&2
exit 9
MOCK
chmod +x "$tmp/pacman" "$tmp/sudo"
export PATH="$tmp:$PATH"
bash "$root/bootstrap/install.sh" --check | grep -F 'installed: git'
bash "$root/bootstrap/install.sh" --check | grep -F 'missing: jdk21-openjdk'
if bash "$root/bootstrap/install.sh" --install >/dev/null 2>&1; then
  echo 'FAIL: unattended install without --yes' >&2; exit 1
fi
if bash "$root/bootstrap/install.sh" --unknown >/dev/null 2>&1; then
  echo 'FAIL: invalid bootstrap command accepted' >&2; exit 1
fi
if bash "$root/bootstrap/install.sh" --install-toolchains >/dev/null 2>&1; then
  echo 'FAIL: toolchain installation without confirmation' >&2; exit 1
fi
echo 'bootstrap check tests passed'

# ---- B1/B2: read-only --check and --plan, with a fully isolated PATH and HOME ----
sys="$tmp/sys"; bin="$tmp/bin"; home="$tmp/home"
mkdir -p "$sys" "$bin" "$home/.local/bin"
for t in bash env grep awk df id uname head tr cat sort dirname mktemp sed cut; do
  p="$(command -v "$t")" && ln -sf "$p" "$sys/$t"
done
mock() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$bin/$1"; chmod +x "$bin/$1"; }
reset_mocks() { rm -f "$bin"/*; 
  mock pacman 'case "$1" in -Qq) [[ " ${MOCK_INSTALLED:-} " == *" $2 "* ]] ;; *) exit 9 ;; esac'
  mock sudo 'echo "sudo must not run in read-only modes" >&2; exit 9'
  mock id '[[ "$1" == -u ]] && echo "${MOCK_UID:-1000}" || /usr/bin/id "$@"'
}
run() { env -i HOME="$home" PATH="$bin:$sys" BXCACHY_SKIP_NETWORK=1 BXCACHY_OS_RELEASE="${OSREL:-$tmp/os-arch}" MOCK_INSTALLED="${MOCK_INSTALLED:-}" MOCK_UID="${MOCK_UID:-1000}" "$@"; }
printf 'ID=cachyos\nID_LIKE=arch\n' > "$tmp/os-arch"
printf 'ID=ubuntu\nID_LIKE=debian\n' > "$tmp/os-ubuntu"
need() { grep -Fq -- "$2" <<<"$1" || { echo "FAIL: expected '$2' in output:" >&2; echo "$1" >&2; exit 1; }; }
refuse() { if grep -Fq -- "$2" <<<"$1"; then echo "FAIL: unexpected '$2' in output:" >&2; echo "$1" >&2; exit 1; fi; }

# 1. Everything missing.
reset_mocks; MOCK_INSTALLED=""
out="$(run bash "$root/bootstrap/install.sh" --check)"
for s in 'os: cachyos (supported)' 'user: normal' 'sudo: available' 'network: skipped' 'missing: jdk21-openjdk' 'missing: base-devel' 'missing: yay' 'java: missing (want 21)' 'matchbox: missing (want 0.12.0)' 'boxlang: missing (want 1.19.0)' 'bxcachy: missing' 'step(s) needed'; do need "$out" "$s"; done
plan="$(run bash "$root/bootstrap/install.sh" --plan)"
for s in 'Nothing below has been run' '1. packages' 'sudo pacman -Syu --needed jdk21-openjdk git curl unzip rustup base-devel' 'upgrades the system' 'sudo pacman -S --needed yay' 'download and run https://install-bvm.boxlang.io' 'mvm install 0.12.0' 'bvm install 1.19.0' 'rustup default stable' 'matchbox --target native src/bxcachy.bxs' 'typed EXECUTE or --allow-external-scripts'; do need "$plan" "$s"; done

# 2. Everything present at the pinned versions: nothing to do.
reset_mocks; MOCK_INSTALLED="jdk21-openjdk git curl unzip rustup base-devel"
mock sudo 'exit 9'
mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'
mock mvm 'echo "MVM version: 2.0.1"'
mock matchbox 'echo "MatchBox 0.12.0"'
mock bvm 'echo "bvm 1.40.0"'
mock boxlang 'echo "Ortus BoxLang v1.19.0+67"'
mock rustc 'echo "rustc 1.90.0 (abc 2026-01-01)"'
mock rustup 'exit 0'
mock yay 'exit 0'
mock bxcachy '[[ "$1" == version ]] && echo "BxCachy 0.11.0-dev"'
cp "$bin/bxcachy" "$home/.local/bin/bxcachy"; rm "$bin/bxcachy"
out="$(run bash "$root/bootstrap/install.sh" --check)"
for s in 'installed: yay' 'java: 21.0.13' 'matchbox: 0.12.0' 'boxlang: 1.19.0' 'rust: 1.90.0' 'bxcachy: 0.11.0' 'bin-dir: '; do need "$out" "$s"; done
need "$out" 'not-on-PATH'; need "$out" '1 step(s) needed'   # only the PATH step remains
plan="$(run bash "$root/bootstrap/install.sh" --plan)"; need "$plan" 'add '; need "$plan" '/.local/bin to PATH'
out="$(env -i HOME="$home" PATH="$home/.local/bin:$bin:$sys" BXCACHY_SKIP_NETWORK=1 BXCACHY_OS_RELEASE="$tmp/os-arch" MOCK_INSTALLED="$MOCK_INSTALLED" bash "$root/bootstrap/install.sh" --check)"
need "$out" 'summary: ready'
plan="$(env -i HOME="$home" PATH="$home/.local/bin:$bin:$sys" BXCACHY_SKIP_NETWORK=1 BXCACHY_OS_RELEASE="$tmp/os-arch" MOCK_INSTALLED="$MOCK_INSTALLED" bash "$root/bootstrap/install.sh" --plan)"
need "$plan" 'Nothing to do'

# 3. Wrong versions are planned for replacement, right ones are left alone.
mock boxlang 'echo "Ortus BoxLang v1.18.0+10"'; mock matchbox 'echo "MatchBox 0.11.0"'
plan="$(env -i HOME="$home" PATH="$home/.local/bin:$bin:$sys" BXCACHY_SKIP_NETWORK=1 BXCACHY_OS_RELEASE="$tmp/os-arch" MOCK_INSTALLED="$MOCK_INSTALLED" bash "$root/bootstrap/install.sh" --plan)"
need "$plan" 'bvm install 1.19.0'; need "$plan" 'mvm install 0.12.0'; refuse "$plan" 'download and run'; refuse "$plan" 'sudo pacman'

# 4. Root, unsupported OS, wrong arguments.
out="$(MOCK_UID=0 run bash "$root/bootstrap/install.sh" --check)"; need "$out" 'user: root (run as a normal user)'
out="$(OSREL="$tmp/os-ubuntu" run bash "$root/bootstrap/install.sh" --check)"; need "$out" 'os: ubuntu (unsupported)'
if run bash "$root/bootstrap/install.sh" --plan extra >/dev/null 2>&1; then echo 'FAIL: --plan accepted an argument' >&2; exit 1; fi
if run bash "$root/bootstrap/install.sh" --check --yes >/dev/null 2>&1; then echo 'FAIL: --check accepted --yes' >&2; exit 1; fi
echo 'bootstrap check/plan tests passed'

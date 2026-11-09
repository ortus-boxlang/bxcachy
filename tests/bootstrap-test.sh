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
for t in bash env grep awk df id uname head tr cat sort dirname mktemp sed cut mkdir chmod rm wc sha256sum basename ls; do
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

# ---- B3: toolchain install behind the EXECUTE gate (all downloads are mocked) ----
MVM_FAKE='mkdir -p "$HOME/.mvm/bin"
cat > "$HOME/.mvm/bin/mvm" <<"M"
#!/usr/bin/env bash
case "$1" in
  install) : ;;
  use) printf "#!/usr/bin/env bash\necho \"MatchBox %s\"\n" "$2" > "$HOME/.mvm/bin/matchbox"; chmod +x "$HOME/.mvm/bin/matchbox" ;;
  --version) echo "MVM version: 2.0.1" ;;
esac
M
chmod +x "$HOME/.mvm/bin/mvm"
echo "MARK-MVM-RAN" >> "$HOME/ran.log"'
BVM_FAKE='mkdir -p "$HOME/.bvm/bin"
cat > "$HOME/.bvm/bin/bvm" <<"M"
#!/usr/bin/env bash
case "$1" in
  install) : ;;
  use) printf "#!/usr/bin/env bash\necho \"Ortus BoxLang v%s+1\"\n" "$2" > "$HOME/.bvm/bin/boxlang"; chmod +x "$HOME/.bvm/bin/boxlang" ;;
  --version) echo "bvm 1.40.0" ;;
esac
M
chmod +x "$HOME/.bvm/bin/bvm"
echo "MARK-BVM-RAN" >> "$HOME/ran.log"'
export MVM_FAKE BVM_FAKE
fresh_home() { rm -rf "$home"; mkdir -p "$home/.local/bin"; : > "$tmp/curl.log"; }
reset_mocks; MOCK_INSTALLED="jdk21-openjdk git curl unzip rustup base-devel"
mock sudo 'exit 9'
mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'
mock curl 'url=""; out=""; while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2 ;; http*) url="$1"; shift ;; *) shift ;; esac; done
echo "$url" >> "$CURL_LOG"
[[ "${MOCK_CURL_FAIL:-0}" == 1 ]] && exit 22
case "$url" in
  *matchbox-quick-installer*) printf "%s\n" "$MVM_FAKE" > "$out" ;;
  *install-bvm*) printf "%s\n" "$BVM_FAKE" > "$out" ;;
  *) exit 22 ;;
esac'
trun() { env -i HOME="$home" PATH="$bin:$sys" BXCACHY_SKIP_NETWORK=1 BXCACHY_OS_RELEASE="$tmp/os-arch" MOCK_INSTALLED="$MOCK_INSTALLED" CURL_LOG="$tmp/curl.log" MVM_FAKE="$MVM_FAKE" BVM_FAKE="$BVM_FAKE" "$@"; }

# 1. Unattended without the flag: refuses, runs nothing.
fresh_home
if out="$(trun bash "$root/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)"; then echo 'FAIL: unattended run without --allow-external-scripts succeeded' >&2; exit 1; fi
need "$out" 'Re-run with --allow-external-scripts'
[[ ! -e "$home/.mvm" && ! -e "$home/.bvm" && ! -e "$home/ran.log" ]] || { echo 'FAIL: something ran without approval' >&2; exit 1; }

# 2. Interactive: wrong answer cancels, typed EXECUTE proceeds.
fresh_home
if out="$(echo no | trun env BXCACHY_INTERACTIVE=1 bash "$root/bootstrap/install.sh" --install-toolchains --yes 2>&1)"; then echo 'FAIL: cancelled run succeeded' >&2; exit 1; fi
need "$out" 'Cancelled. Nothing was run.'; [[ ! -e "$home/ran.log" ]] || { echo 'FAIL: script ran after cancel' >&2; exit 1; }
printf 'EXECUTE\nEXECUTE\n' | trun env BXCACHY_INTERACTIVE=1 bash "$root/bootstrap/install.sh" --install-toolchains --yes >/dev/null 2>&1 || { echo 'FAIL: typed EXECUTE did not proceed' >&2; exit 1; }
grep -q MARK-MVM-RAN "$home/ran.log" && grep -q MARK-BVM-RAN "$home/ran.log" || { echo 'FAIL: installers did not run after EXECUTE' >&2; exit 1; }

# 3. Flag approves; end state is at the pins; the script shows url, sha256 and its first lines.
fresh_home
out="$(trun bash "$root/bootstrap/install.sh" --install-toolchains --yes --allow-external-scripts </dev/null 2>&1)"
for x in 'External script: mvm' 'External script: bvm' 'sha256: ' 'first lines:' 'approved by --allow-external-scripts' 'MatchBox 0.12.0 installed and verified.' 'BoxLang 1.19.0 installed and verified.'; do need "$out" "$x"; done
chk="$(trun env PATH="$home/.local/bin:$bin:$sys" bash "$root/bootstrap/install.sh" --check)"; need "$chk" 'matchbox: 0.12.0'; need "$chk" 'boxlang: 1.19.0'
[[ "$(stat -c %a "$home/.cache/bxcachy/external")" == 700 ]] || { echo 'FAIL: cache dir not private' >&2; exit 1; }

# 4. Second run: nothing to do, nothing downloaded.
: > "$tmp/curl.log"
out="$(trun bash "$root/bootstrap/install.sh" --install-toolchains --yes --allow-external-scripts </dev/null 2>&1)"
need "$out" 'Nothing to do'; [[ ! -s "$tmp/curl.log" ]] || { echo 'FAIL: rerun downloaded something' >&2; exit 1; }

# 5. Partial state: MVM+MatchBox present, BVM missing -> only the BVM script is fetched.
rm -rf "$home/.bvm"; : > "$tmp/curl.log"
trun bash "$root/bootstrap/install.sh" --install-toolchains --yes --allow-external-scripts </dev/null >/dev/null 2>&1
[[ "$(wc -l < "$tmp/curl.log")" == 1 ]] && grep -q install-bvm "$tmp/curl.log" || { echo 'FAIL: partial recovery fetched the wrong scripts' >&2; cat "$tmp/curl.log" >&2; exit 1; }

# 6. Failures: download error, wrong Java, root, unknown flag.
fresh_home
if out="$(trun env MOCK_CURL_FAIL=1 bash "$root/bootstrap/install.sh" --install-toolchains --yes --allow-external-scripts </dev/null 2>&1)"; then echo 'FAIL: download failure ignored' >&2; exit 1; fi
need "$out" 'Download failed'
mock java 'echo "openjdk version \"17.0.9\" 2024-01-01" >&2'
if out="$(trun bash "$root/bootstrap/install.sh" --install-toolchains --yes --allow-external-scripts </dev/null 2>&1)"; then echo 'FAIL: wrong Java accepted' >&2; exit 1; fi; need "$out" 'Java 21 is required'
mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'
if out="$(trun env MOCK_UID=0 bash "$root/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)"; then echo 'FAIL: root accepted' >&2; exit 1; fi; need "$out" 'regular user'
if trun bash "$root/bootstrap/install.sh" --install-toolchains --yes --bogus >/dev/null 2>&1; then echo 'FAIL: unknown flag accepted' >&2; exit 1; fi
if trun bash "$root/bootstrap/install.sh" --install --yes --allow-external-scripts >/dev/null 2>&1; then echo 'FAIL: --install accepted the external-scripts flag' >&2; exit 1; fi
echo 'bootstrap toolchain tests passed'

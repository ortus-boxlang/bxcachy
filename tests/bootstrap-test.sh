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
for t in bash env grep awk df id uname head tr cat sort dirname mktemp sed cut mkdir chmod rm wc sha256sum basename ls cp mv find cmp tail stat readlink ln jq; do
  p="$(command -v "$t")" && ln -sf "$p" "$sys/$t"
done
# Fixture repository: a copy of the script next to a box.json with known pins. Tests run this copy.
repo="$tmp/repo"; mkdir -p "$repo/bootstrap" "$repo/src"
cp "$root/bootstrap/install.sh" "$repo/bootstrap/install.sh"; cp -r "$root/src/." "$repo/src/"
cat > "$repo/box.json" <<'JSON'
{ "name": "bxcachy", "version": "0.11.0-dev",
  "toolchain": {
    "java": { "version": "21", "package": "jdk21-openjdk" },
    "boxlang": { "version": "latest" },
    "bvm": { "version": "latest", "installer": "https://install-bvm.boxlang.io" },
    "mvm": { "version": "latest", "installer": "https://raw.githubusercontent.com/ortus-boxlang/matchbox-quick-installer/main/install/install.sh" },
    "matchbox": { "version": "0.12.0" },
    "rust": { "channel": "stable" },
    "nvm": { "version": "v0.41.0", "installer": "https://raw.githubusercontent.com/nvm-sh/nvm/v0.41.0/install.sh", "node": "lts/*" } } }
JSON
REALJQ="$(command -v jq)"
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
out="$(run bash "$repo/bootstrap/install.sh" --check)"
for s in 'os: cachyos (supported)' 'user: normal' 'sudo: available' 'network: skipped' 'missing: jdk21-openjdk' 'missing: base-devel' 'missing: yay' 'missing: jq' 'java: missing (want 21)' 'matchbox: missing (want 0.12.0)' 'boxlang: missing (want latest, version lookup unavailable)' 'bxcachy: missing' 'step(s) needed'; do need "$out" "$s"; done
plan="$(run bash "$repo/bootstrap/install.sh" --plan)"
for s in 'Nothing below has been run' '1. packages' 'sudo pacman -Syu --needed jdk21-openjdk git curl unzip rustup base-devel' 'upgrades the system' 'sudo pacman -S --needed yay' 'download and run https://install-bvm.boxlang.io' 'mvm install 0.12.0' 'bvm install latest' 'rustup default stable' 'install.sh --install-binary --yes' 'external script, shown and run'; do need "$plan" "$s"; done

# 2. Everything present at the pinned versions: nothing to do.
reset_mocks; MOCK_INSTALLED="jdk21-openjdk git curl unzip rustup base-devel jq"
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
# nvm and Node.js present (a fake nvm.sh and node)
mkdir -p "$home/.nvm/bin"
printf '%s\n' 'nvm() { case "$1" in --version) echo 0.41.0 ;; esac; }' '[ -x "$NVM_DIR/bin/node" ] && export PATH="$NVM_DIR/bin:$PATH"' 'true' > "$home/.nvm/nvm.sh"
printf '#!/usr/bin/env bash\necho v22.11.0\n' > "$home/.nvm/bin/node"; chmod +x "$home/.nvm/bin/node"
out="$(run bash "$repo/bootstrap/install.sh" --check)"
for s in 'installed: yay' 'java: 21.0.13' 'matchbox: 0.12.0' 'boxlang: 1.19.0' 'nvm: 0.41.0' 'node: 22.11.0' 'rust: 1.90.0' 'bxcachy: 0.11.0' 'bin-dir: '; do need "$out" "$s"; done
need "$out" 'not-on-PATH'; need "$out" '1 step(s) needed'   # only the PATH step remains
plan="$(run bash "$repo/bootstrap/install.sh" --plan)"; need "$plan" 'add '; need "$plan" '/.local/bin to PATH'
out="$(env -i HOME="$home" PATH="$home/.local/bin:$bin:$sys" BXCACHY_SKIP_NETWORK=1 BXCACHY_OS_RELEASE="$tmp/os-arch" MOCK_INSTALLED="$MOCK_INSTALLED" bash "$repo/bootstrap/install.sh" --check)"
need "$out" 'summary: ready'
plan="$(env -i HOME="$home" PATH="$home/.local/bin:$bin:$sys" BXCACHY_SKIP_NETWORK=1 BXCACHY_OS_RELEASE="$tmp/os-arch" MOCK_INSTALLED="$MOCK_INSTALLED" bash "$repo/bootstrap/install.sh" --plan)"
need "$plan" 'Nothing to do'

# 3. Wrong versions are planned for replacement, right ones are left alone.
mock boxlang 'echo "Ortus BoxLang v1.18.0+10"'; mock matchbox 'echo "MatchBox 0.11.0"'
mock curl 'printf "version=1.19.0+67\nbuildDate=x\n"'
plan="$(env -i HOME="$home" PATH="$home/.local/bin:$bin:$sys" BXCACHY_SKIP_NETWORK=1 BXCACHY_OS_RELEASE="$tmp/os-arch" MOCK_INSTALLED="$MOCK_INSTALLED" bash "$repo/bootstrap/install.sh" --plan)"
need "$plan" 'update BoxLang 1.18.0 to 1.19.0'; need "$plan" 'bvm install latest'; need "$plan" 'mvm install 0.12.0'; refuse "$plan" 'download and run'; refuse "$plan" 'sudo pacman'

# 4. Root, unsupported OS, wrong arguments.
out="$(MOCK_UID=0 run bash "$repo/bootstrap/install.sh" --check)"; need "$out" 'user: root (run as a normal user)'
out="$(OSREL="$tmp/os-ubuntu" run bash "$repo/bootstrap/install.sh" --check)"; need "$out" 'os: ubuntu (unsupported)'
if run bash "$repo/bootstrap/install.sh" --plan extra >/dev/null 2>&1; then echo 'FAIL: --plan accepted an argument' >&2; exit 1; fi
if run bash "$repo/bootstrap/install.sh" --check --yes >/dev/null 2>&1; then echo 'FAIL: --check accepted --yes' >&2; exit 1; fi
echo 'bootstrap check/plan tests passed'

# ---- B3: toolchain install, external installers run without a gate (all downloads are mocked) ----
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
  use) v="$2"; [[ "$v" == latest ]] && v="${MOCK_LATEST:-1.19.0}"; printf "#!/usr/bin/env bash\necho \"Ortus BoxLang v%s+1\"\n" "$v" > "$HOME/.bvm/bin/boxlang"; chmod +x "$HOME/.bvm/bin/boxlang" ;;
  --version) echo "bvm 1.40.0" ;;
esac
M
chmod +x "$HOME/.bvm/bin/bvm"
echo "MARK-BVM-RAN" >> "$HOME/ran.log"'
NVM_FAKE='mkdir -p "$HOME/.nvm"
cat > "$HOME/.nvm/nvm.sh" <<"M"
# fake nvm: a shell function plus node on the PATH once "nvm install" ran
nvm() {
  case "$1" in
    --version) echo "0.41.0" ;;
    install) mkdir -p "$NVM_DIR/bin"; printf "#!/usr/bin/env bash\necho v22.11.0\n" > "$NVM_DIR/bin/node"; chmod +x "$NVM_DIR/bin/node" ;;
    alias) : ;;
  esac
}
[ -x "$NVM_DIR/bin/node" ] && export PATH="$NVM_DIR/bin:$PATH"
true
M
echo "MARK-NVM-RAN" >> "$HOME/ran.log"'
export MVM_FAKE BVM_FAKE NVM_FAKE
fresh_home() { rm -rf "$home"; mkdir -p "$home/.local/bin"; : > "$tmp/curl.log"; }
reset_mocks; MOCK_INSTALLED="jdk21-openjdk git curl unzip rustup base-devel jq"
mock sudo 'exit 9'
mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'
mock curl 'url=""; out=""; while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2 ;; http*) url="$1"; shift ;; *) shift ;; esac; done
[[ -n "$out" ]] && echo "$url" >> "$CURL_LOG"
[[ "${MOCK_CURL_FAIL:-0}" == 1 ]] && exit 22
case "$url" in
  *matchbox-quick-installer*) printf "%s\n" "$MVM_FAKE" > "$out" ;;
  *install-bvm*) printf "%s\n" "$BVM_FAKE" > "$out" ;; *nvm-sh/nvm*) printf "%s\n" "$NVM_FAKE" > "$out" ;;
  *version-latest.properties*) printf "version=%s+1\nbuildDate=x\n" "${MOCK_LATEST:-1.19.0}" ;;
  *) exit 22 ;;
esac'
trun() { env -i HOME="$home" MOCK_LATEST="${MOCK_LATEST:-1.19.0}" PATH="$bin:$sys" BXCACHY_SKIP_NETWORK=1 BXCACHY_OS_RELEASE="$tmp/os-arch" MOCK_INSTALLED="$MOCK_INSTALLED" CURL_LOG="$tmp/curl.log" MVM_FAKE="$MVM_FAKE" BVM_FAKE="$BVM_FAKE" NVM_FAKE="$NVM_FAKE" "$@"; }

# 1. Runs unattended; end state is at the pins; each script shows its url and sha256.
fresh_home
out="$(trun bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)"
for x in 'External script: mvm' 'External script: bvm' 'External script: nvm' 'Node.js 22.11.0 installed with nvm and verified.' 'sha256: ' 'MatchBox 0.12.0 installed and verified.' 'BoxLang 1.19.0 installed and verified.'; do need "$out" "$x"; done
chk="$(trun env PATH="$home/.local/bin:$bin:$sys" bash "$repo/bootstrap/install.sh" --check)"; need "$chk" 'matchbox: 0.12.0'; need "$chk" 'boxlang: 1.19.0'
[[ "$(stat -c %a "$home/.cache/bxcachy/external")" == 700 ]] || { echo 'FAIL: cache dir not private' >&2; exit 1; }

# 4. Second run: nothing to do, nothing downloaded.
: > "$tmp/curl.log"
out="$(trun bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)"
need "$out" 'Nothing to do'; [[ ! -s "$tmp/curl.log" ]] || { echo 'FAIL: rerun downloaded something' >&2; exit 1; }

# 5. Partial state: MVM+MatchBox present, BVM missing -> only the BVM script is fetched.
rm -rf "$home/.bvm"; : > "$tmp/curl.log"
trun bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null >/dev/null 2>&1
[[ "$(wc -l < "$tmp/curl.log")" == 1 ]] && grep -q install-bvm "$tmp/curl.log" || { echo 'FAIL: partial recovery fetched the wrong scripts' >&2; cat "$tmp/curl.log" >&2; exit 1; }

# 6. Failures: download error, wrong Java, root, unknown flag.
fresh_home
if out="$(trun env MOCK_CURL_FAIL=1 bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)"; then echo 'FAIL: download failure ignored' >&2; exit 1; fi
need "$out" 'Download failed'
mock java 'echo "openjdk version \"17.0.9\" 2024-01-01" >&2'
if out="$(trun bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)"; then echo 'FAIL: wrong Java accepted' >&2; exit 1; fi; need "$out" 'Java 21 is required'
mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'
if out="$(trun env MOCK_UID=0 bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)"; then echo 'FAIL: root accepted' >&2; exit 1; fi; need "$out" 'regular user'
if trun bash "$repo/bootstrap/install.sh" --install-toolchains --yes --bogus >/dev/null 2>&1; then echo 'FAIL: unknown flag accepted' >&2; exit 1; fi
echo 'bootstrap toolchain tests passed'

# ---- B4: --install installs missing packages, yay only if absent, and Rust; reruns change nothing ----
install_mocks() {
  reset_mocks; : > "$tmp/pacman.log"; : > "$tmp/state"
  mock pacman 'case "$1" in
  -Qq) grep -qx -- "$2" "$STATE" ;;
  -Syu) shift; echo "Syu $*" >> "$PLOG"; [[ "${MOCK_SYU_FAIL:-0}" == 1 ]] && exit 1; for p in "$@"; do [[ "$p" == --needed ]] || echo "$p" >> "$STATE"; done ;;
  -S) shift; echo "S $*" >> "$PLOG"; [[ " $* " == *" yay "* && "${MOCK_YAY_FAIL:-0}" == 1 ]] && exit 1
      [[ " $* " == *" yay "* ]] && { printf "#!/usr/bin/env bash\nexit 0\n" > "$BINDIR/yay"; chmod +x "$BINDIR/yay"; }
      [[ " $* " == *" jq "* ]] && { ln -sf "$REALJQ" "$SYSDIR/jq"; echo jq >> "$STATE"; }
      exit 0 ;;
  *) exit 9 ;;
esac'
  mock sudo '"$@"'
  mock rustup '[[ "${MOCK_RUSTUP_FAIL:-0}" == 1 ]] && exit 1; if [[ "$1 $2" == "default stable" ]]; then echo "rustup $*" >> "$PLOG"; printf "#!/usr/bin/env bash\necho \"rustc 1.90.0\"\n" > "$BINDIR/rustc"; chmod +x "$BINDIR/rustc"; fi'
  mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'
}
irun() { env -i HOME="$home" PATH="$bin:$sys" BXCACHY_SKIP_NETWORK=1 BXCACHY_OS_RELEASE="$tmp/os-arch" STATE="$tmp/state" PLOG="$tmp/pacman.log" BINDIR="$bin" REALJQ="$REALJQ" SYSDIR="$sys" MOCK_UID="${MOCK_UID:-1000}" MOCK_YAY_FAIL="${MOCK_YAY_FAIL:-0}" MOCK_SYU_FAIL="${MOCK_SYU_FAIL:-0}" MOCK_RUSTUP_FAIL="${MOCK_RUSTUP_FAIL:-0}" "$@"; }

install_mocks; fresh_home
out="$(irun bash "$repo/bootstrap/install.sh" --install --yes 2>&1)"
log="$(cat "$tmp/pacman.log")"
need "$log" 'Syu --noconfirm --needed jdk21-openjdk git curl unzip rustup base-devel'; need "$log" 'S --noconfirm --needed yay'; need "$log" 'rustup default stable'
need "$out" 'does not edit shell startup files'; need "$out" 'Next: install.sh --install-toolchains --yes'
before="$(wc -l < "$tmp/pacman.log")"
out="$(irun bash "$repo/bootstrap/install.sh" --install --yes 2>&1)"
need "$out" 'packages: all installed'; need "$out" 'yay: already installed'; need "$out" 'Nothing to do for packages, yay and Rust.'
[[ "$(wc -l < "$tmp/pacman.log")" == "$before" ]] || { echo 'FAIL: rerun changed the system again' >&2; cat "$tmp/pacman.log" >&2; exit 1; }

# Only the missing package is requested, and yay is skipped when present.
install_mocks; fresh_home; echo "git" >> "$tmp/state"; echo "curl" >> "$tmp/state"; mock yay 'exit 0'
irun bash "$repo/bootstrap/install.sh" --install --yes >/dev/null 2>&1
log="$(cat "$tmp/pacman.log")"; need "$log" 'Syu --noconfirm --needed jdk21-openjdk unzip rustup base-devel'; refuse "$log" 'S --noconfirm --needed yay'

# At a terminal pacman is left to ask itself: no --noconfirm.
install_mocks; fresh_home
irun env BXCACHY_INTERACTIVE=1 bash "$repo/bootstrap/install.sh" --install --yes >/dev/null 2>&1
log="$(cat "$tmp/pacman.log")"; need "$log" 'Syu --needed jdk21-openjdk'; refuse "$log" '--noconfirm'

# Failure paths: yay unavailable, root.
install_mocks; fresh_home
if out="$(MOCK_YAY_FAIL=1 irun bash "$repo/bootstrap/install.sh" --install --yes 2>&1)"; then echo 'FAIL: missing yay ignored' >&2; exit 1; fi; need "$out" 'yay is not available'
install_mocks; fresh_home
if out="$(MOCK_UID=0 irun bash "$repo/bootstrap/install.sh" --install --yes 2>&1)"; then echo 'FAIL: --install ran as root' >&2; exit 1; fi; need "$out" 'regular user'
[[ ! -s "$tmp/pacman.log" ]] || { echo 'FAIL: root run touched the system' >&2; exit 1; }
echo 'bootstrap install tests passed'

# ---- B5: --install-binary builds (or accepts) bxcachy, verifies it first, installs atomically ----
SRCVER="$(grep -m1 -oE 'BxCachy [0-9][0-9A-Za-z.+-]*' "$root/src/Main.bx")"
fake_bin() { printf '#!/usr/bin/env bash\n[[ "$1" == version ]] && echo "%s" || echo "other"\n' "$1"; }
b_mocks() {
  reset_mocks; fresh_home
  mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'
  mock matchbox 'if [[ "$1" == --version ]]; then echo "MatchBox ${MOCK_MB:-0.12.0}"; exit 0; fi
[[ "${MOCK_BUILD_FAIL:-0}" == 1 ]] && { echo "boom: compile error" >&2; exit 1; }
echo "$*" >> "$BLOG"
out=bxcachy; while [[ $# -gt 0 ]]; do [[ "$1" == --output ]] && { out="$2"; break; }; shift; done
cp "$FAKE" "$out"; chmod 755 "$out"'
  : > "$tmp/build.log"; fake_bin "$SRCVER" > "$tmp/fake_built"
}
brun() { env -i HOME="$home" PATH="$bin:$sys" BXCACHY_SKIP_NETWORK=1 BLOG="$tmp/build.log" FAKE="$tmp/fake_built" MOCK_UID="${MOCK_UID:-1000}" MOCK_MB="${MOCK_MB:-0.12.0}" MOCK_BUILD_FAIL="${MOCK_BUILD_FAIL:-0}" "$@"; }
dest="$home/.local/bin/bxcachy"

# 1. Build from source and install.
b_mocks
out="$(brun bash "$repo/bootstrap/install.sh" --install-binary --yes 2>&1)"
need "$out" 'Building bxcachy with MatchBox 0.12.0'; need "$out" "Installed $dest ($SRCVER)"
[[ -x "$dest" ]] && [[ "$("$dest" version)" == "$SRCVER" ]] || { echo 'FAIL: binary not installed or not working' >&2; exit 1; }
need "$(cat "$tmp/build.log")" '--target native --output'; need "$(cat "$tmp/build.log")" 'src/Main.bx'
# 2. Same version again: nothing built, nothing replaced. --force rebuilds.
: > "$tmp/build.log"; stamp="$(stat -c %Y-%i "$dest")"
out="$(brun bash "$repo/bootstrap/install.sh" --install-binary --yes 2>&1)"; need "$out" 'Nothing to do'
[[ ! -s "$tmp/build.log" && "$(stat -c %Y-%i "$dest")" == "$stamp" ]] || { echo 'FAIL: rerun rebuilt or replaced the binary' >&2; exit 1; }
brun bash "$repo/bootstrap/install.sh" --install-binary --yes --force >/dev/null 2>&1; [[ -s "$tmp/build.log" ]] || { echo 'FAIL: --force did not rebuild' >&2; exit 1; }
# 3. A failed build or a bad result never touches the installed copy.
fake_bin "BxCachy 0.0.1-old" > "$dest"; chmod 755 "$dest"; old="$(cat "$dest")"
if out="$(MOCK_BUILD_FAIL=1 brun bash "$repo/bootstrap/install.sh" --install-binary --yes --force 2>&1)"; then echo 'FAIL: build failure ignored' >&2; exit 1; fi
need "$out" 'installed copy was not touched'; need "$out" 'compile error'; [[ "$(cat "$dest")" == "$old" ]] || { echo 'FAIL: failed build changed the install' >&2; exit 1; }
fake_bin "oops not it" > "$tmp/fake_built"
if out="$(brun bash "$repo/bootstrap/install.sh" --install-binary --yes --force 2>&1)"; then echo 'FAIL: bad binary accepted' >&2; exit 1; fi
need "$out" 'self-check'; [[ "$(cat "$dest")" == "$old" ]] || { echo 'FAIL: bad binary replaced the install' >&2; exit 1; }
# 4. Prerequisites: wrong or missing MatchBox, root.
if out="$(MOCK_MB=0.11.0 brun bash "$repo/bootstrap/install.sh" --install-binary --yes --force 2>&1)"; then echo 'FAIL: wrong MatchBox accepted' >&2; exit 1; fi; need "$out" 'MatchBox 0.12.0 is required'
if out="$(MOCK_UID=0 brun bash "$repo/bootstrap/install.sh" --install-binary --yes 2>&1)"; then echo 'FAIL: root accepted' >&2; exit 1; fi; need "$out" 'regular user'
# 5. --binary: installs a given file after verifying it; rejects symlinks, non-executables and impostors.
b_mocks; good="$tmp/good"; fake_bin "BxCachy 9.9.9" > "$good"; chmod 755 "$good"
out="$(brun bash "$repo/bootstrap/install.sh" --install-binary --yes --binary "$good" 2>&1)"; need "$out" 'Installed'; [[ "$("$dest" version)" == "BxCachy 9.9.9" ]] || { echo 'FAIL: --binary not installed' >&2; exit 1; }
need "$(brun bash "$repo/bootstrap/install.sh" --install-binary --yes --binary "$good" 2>&1)" 'identical'
ln -sf "$good" "$tmp/link"; printf 'x' > "$tmp/plain"; fake_bin "BxCachy" | sed 's/BxCachy/Other/' > "$tmp/imp"; chmod 755 "$tmp/imp"
for bad in "$tmp/link" "$tmp/plain" "$tmp/imp" "$tmp/missing"; do
  if brun bash "$repo/bootstrap/install.sh" --install-binary --yes --binary "$bad" >/dev/null 2>&1; then echo "FAIL: --binary accepted $bad" >&2; exit 1; fi
done
[[ "$("$dest" version)" == "BxCachy 9.9.9" ]] || { echo 'FAIL: rejected --binary changed the install' >&2; exit 1; }
# 6. Arguments.
if brun bash "$repo/bootstrap/install.sh" --install-binary >/dev/null 2>&1; then echo 'FAIL: --install-binary without --yes' >&2; exit 1; fi
if brun bash "$repo/bootstrap/install.sh" --install-binary --yes --bogus >/dev/null 2>&1; then echo 'FAIL: unknown flag' >&2; exit 1; fi
if brun bash "$repo/bootstrap/install.sh" --install-binary --yes --binary >/dev/null 2>&1; then echo 'FAIL: --binary without a path' >&2; exit 1; fi
echo 'bootstrap binary tests passed'

# ---- B6: failure paths. Every one must say why, and leave the system as it was ----
# Network unreachable is reported, not fatal, for the read-only report.
reset_mocks; mock curl 'exit 22'
out="$(env -i HOME="$home" PATH="$bin:$sys" BXCACHY_OS_RELEASE="$tmp/os-arch" MOCK_INSTALLED="" bash "$repo/bootstrap/install.sh" --check 2>&1)"; need "$out" 'network: unreachable'

# Unsupported OS and too little disk stop every installing mode before anything runs.
install_mocks; fresh_home; mock curl 'exit 22'
for m in "--install --yes" "--install-toolchains --yes"; do
  if out="$(OSREL="$tmp/os-ubuntu" env -i HOME="$home" PATH="$bin:$sys" BXCACHY_SKIP_NETWORK=1 BXCACHY_OS_RELEASE="$tmp/os-ubuntu" STATE="$tmp/state" PLOG="$tmp/pacman.log" BINDIR="$bin" bash "$repo/bootstrap/install.sh" $m 2>&1 </dev/null)"; then echo "FAIL: '$m' ran on an unsupported OS" >&2; exit 1; fi
  need "$out" 'Unsupported OS: ubuntu'
done
[[ ! -s "$tmp/pacman.log" ]] || { echo 'FAIL: unsupported OS touched the system' >&2; exit 1; }
mock df 'printf "Filesystem 1024-blocks Used Available Capacity Mounted\nx 100 50 1024 5%% /\n"'
if out="$(irun bash "$repo/bootstrap/install.sh" --install --yes 2>&1)"; then echo 'FAIL: low disk accepted' >&2; exit 1; fi; need "$out" 'Not enough free disk space'
[[ ! -s "$tmp/pacman.log" ]] || { echo 'FAIL: low disk touched the system' >&2; exit 1; }
rm -f "$bin/df"

# sudo missing, pacman failing, rustup failing.
install_mocks; fresh_home; rm -f "$bin/sudo"
if out="$(irun bash "$repo/bootstrap/install.sh" --install --yes 2>&1)"; then echo 'FAIL: missing sudo ignored' >&2; exit 1; fi; need "$out" 'sudo is required'
install_mocks; fresh_home
if out="$(MOCK_SYU_FAIL=1 irun bash "$repo/bootstrap/install.sh" --install --yes 2>&1)"; then echo 'FAIL: pacman failure ignored' >&2; exit 1; fi
need "$out" 'pacman failed; nothing else was changed'; refuse "$(cat "$tmp/pacman.log")" 'S --noconfirm --needed yay'
install_mocks; fresh_home; echo jdk21-openjdk >> "$tmp/state"; for q in git curl unzip rustup base-devel jq; do echo $q >> "$tmp/state"; done; mock yay 'exit 0'
if out="$(MOCK_RUSTUP_FAIL=1 irun bash "$repo/bootstrap/install.sh" --install --yes 2>&1)"; then echo 'FAIL: rustup failure ignored' >&2; exit 1; fi; need "$out" 'rustup could not install'

# Interrupted toolchain install: the MVM installer dies midway; a later run resumes and finishes.
reset_mocks; MOCK_INSTALLED="jdk21-openjdk git curl unzip rustup base-devel jq"
mock sudo 'exit 9'; mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'
mock curl 'url=""; out=""; while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2 ;; http*) url="$1"; shift ;; *) shift ;; esac; done
[[ -n "$out" ]] && echo "$url" >> "$CURL_LOG"
case "$url" in *matchbox-quick-installer*) printf "%s\n" "$MVM_FAKE" > "$out" ;; *install-bvm*) printf "%s\n" "$BVM_FAKE" > "$out" ;; *nvm-sh/nvm*) printf "%s\n" "$NVM_FAKE" > "$out" ;; *version-latest.properties*) printf "version=%s+1\nbuildDate=x\n" "${MOCK_LATEST:-1.19.0}" ;; *) exit 22 ;; esac'
fresh_home
GOOD_MVM="$MVM_FAKE"
if out="$(MVM_FAKE='echo half-done; exit 1' trun bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)"; then echo 'FAIL: dying installer treated as success' >&2; exit 1; fi
need "$out" 'mvm installer failed (script kept at'
[[ ! -e "$home/.bvm" ]] || { echo 'FAIL: later steps ran after a failed one' >&2; exit 1; }
out="$(MVM_FAKE="$GOOD_MVM" trun bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)"
need "$out" 'BoxLang 1.19.0 installed and verified.'
# A failing "bvm install" is named, not silent.
fresh_home; rm -rf "$home/.bvm"; : > "$tmp/curl.log"
BAD_BVM="${BVM_FAKE/install) : ;;/install) exit 1 ;;}"
if out="$(BVM_FAKE="$BAD_BVM" trun bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)"; then echo 'FAIL: bvm install failure ignored' >&2; exit 1; fi
need "$out" 'Failed: bvm install latest'
echo 'bootstrap failure-path tests passed'

# ---- Routine probes must not start the BoxLang runtime (it rewrites its own logs on every start) ----
reset_mocks; fresh_home; MOCK_INSTALLED="jdk21-openjdk git curl unzip rustup base-devel jq"
mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'
mock boxlang 'echo ran >> "$HOME/boxlang-ran"; echo "Ortus BoxLang v9.9.9+1"'
mkdir -p "$home/.bvm/versions/1.19.0"; ln -s "$home/.bvm/versions/1.19.0" "$home/.bvm/current"; ln -sf "$bin/boxlang" "$home/.bvm/bin-boxlang" 2>/dev/null || true
out="$(run bash "$repo/bootstrap/install.sh" --check)"; need "$out" 'boxlang: 1.19.0 (want latest, version lookup unavailable)'
run bash "$repo/bootstrap/install.sh" --plan >/dev/null
[[ ! -e "$home/boxlang-ran" ]] || { echo 'FAIL: a read-only probe started the BoxLang runtime' >&2; exit 1; }
# Without BVM's symlink, it falls back to asking boxlang itself.
rm "$home/.bvm/current"; out="$(run bash "$repo/bootstrap/install.sh" --check)"; need "$out" 'boxlang: 9.9.9'
echo 'bootstrap probe tests passed'

# ---- BoxLang follows the latest stable release; MatchBox stays pinned ----
reset_mocks; MOCK_INSTALLED="jdk21-openjdk git curl unzip rustup base-devel jq"
mock sudo 'exit 9'; mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'
mock curl 'url=""; out=""; while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2 ;; http*) url="$1"; shift ;; *) shift ;; esac; done
[[ -n "$out" ]] && echo "$url" >> "$CURL_LOG"
case "$url" in *matchbox-quick-installer*) printf "%s\n" "$MVM_FAKE" > "$out" ;; *install-bvm*) printf "%s\n" "$BVM_FAKE" > "$out" ;; *nvm-sh/nvm*) printf "%s\n" "$NVM_FAKE" > "$out" ;; *version-latest.properties*) printf "version=%s+1\nbuildDate=x\n" "${MOCK_LATEST:-1.19.0}" ;; *) exit 22 ;; esac'
fresh_home
out="$(trun bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)"; need "$out" 'BoxLang 1.19.0 installed and verified.'
chk="$(trun env PATH="$home/.local/bin:$bin:$sys" bash "$repo/bootstrap/install.sh" --check)"; need "$chk" 'boxlang: 1.19.0 (want latest = 1.19.0)'
# Upstream ships a newer BoxLang: the next run updates it with `bvm`, downloads no installer script.
: > "$tmp/curl.log"
chk="$(MOCK_LATEST=1.20.0 trun env PATH="$home/.local/bin:$bin:$sys" bash "$repo/bootstrap/install.sh" --plan)"; need "$chk" 'update BoxLang 1.19.0 to 1.20.0'
out="$(MOCK_LATEST=1.20.0 trun bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)"; need "$out" 'BoxLang 1.20.0 installed and verified.'
[[ ! -s "$tmp/curl.log" ]] || { echo 'FAIL: updating BoxLang downloaded an installer script' >&2; cat "$tmp/curl.log" >&2; exit 1; }
# Already latest: nothing to do. Lookup unavailable: the installed version is left alone, and says so.
out="$(MOCK_LATEST=1.20.0 trun bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)"; need "$out" 'Nothing to do'
mock curl 'exit 22'   # curl exists but the lookup fails (offline)
out="$(trun bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)"; need "$out" 'could not look up the latest version'
# A pinned BoxLang is honored.
chk="$(trun env BXCACHY_BOXLANG_VERSION=1.19.0 bash "$repo/bootstrap/install.sh" --check)"; need "$chk" '(want 1.19.0 (pinned))'
echo 'bootstrap latest-BoxLang tests passed'

# ---- box.json: the one place that names tool versions ----
# The real manifest is valid, complete and agrees with the source's version string.
for k in .name .version .toolchain.java.version .toolchain.java.package .toolchain.boxlang.version .toolchain.bvm.installer .toolchain.mvm.installer .toolchain.matchbox.version .toolchain.rust.channel; do
  jq -e "$k" "$root/box.json" >/dev/null || { echo "FAIL: real box.json lacks $k" >&2; exit 1; }
done
[[ "BxCachy $(jq -r .version "$root/box.json")" == "$(grep -m1 -oE 'BxCachy [0-9][0-9A-Za-z.+-]*' "$root/src/Main.bx")" ]] || { echo 'FAIL: box.json version differs from the version in src/Main.bx' >&2; exit 1; }
# A different pin in box.json changes the plan (no copy of the version lives in the script).
reset_mocks; MOCK_INSTALLED="jdk21-openjdk git curl unzip rustup base-devel jq"; mock sudo 'exit 9'
jq '.toolchain.matchbox.version="0.13.0" | .toolchain.rust.channel="beta" | .toolchain.java.package="jdk-test-openjdk"' "$repo/box.json" > "$tmp/box-other.json"
plan="$(run env BXCACHY_MANIFEST="$tmp/box-other.json" bash "$repo/bootstrap/install.sh" --plan)"
need "$plan" 'mvm install 0.13.0'; need "$plan" 'rustup default beta'; need "$plan" 'jdk-test-openjdk'
# BXCACHY_BOXLANG_VERSION still beats the manifest.
chk="$(run env BXCACHY_BOXLANG_VERSION=1.18.0 bash "$repo/bootstrap/install.sh" --check)"; need "$chk" '(want 1.18.0 (pinned))'
# A broken manifest is an error that says what is wrong.
echo '{ not json' > "$tmp/box-bad.json"
if out="$(run env BXCACHY_MANIFEST="$tmp/box-bad.json" bash "$repo/bootstrap/install.sh" --check 2>&1)"; then echo 'FAIL: invalid box.json accepted' >&2; exit 1; fi; need "$out" 'not valid JSON'
jq 'del(.toolchain.matchbox.version)' "$repo/box.json" > "$tmp/box-gap.json"
if out="$(run env BXCACHY_MANIFEST="$tmp/box-gap.json" bash "$repo/bootstrap/install.sh" --plan 2>&1)"; then echo 'FAIL: incomplete box.json accepted' >&2; exit 1; fi; need "$out" 'missing toolchain.matchbox.version'
if out="$(run env BXCACHY_MANIFEST="$tmp/nope.json" bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)"; then echo 'FAIL: missing box.json accepted' >&2; exit 1; fi; need "$out" 'box.json not found'
# Without jq the read-only modes explain what to do, and the installing modes point at --install.
rm -f "$sys/jq"
out="$(run bash "$repo/bootstrap/install.sh" --check 2>&1)"; need "$out" 'jq is required to read box.json'
plan="$(run bash "$repo/bootstrap/install.sh" --plan 2>&1)"; need "$plan" 'sudo pacman -S --needed jq'
if out="$(run bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)"; then echo 'FAIL: toolchains ran without jq' >&2; exit 1; fi; need "$out" 'Run install.sh --install --yes first'
# --install installs jq first, then carries on with the manifest.
install_mocks; fresh_home; rm -f "$sys/jq"
out="$(irun bash "$repo/bootstrap/install.sh" --install --yes 2>&1)"
need "$out" 'Installing jq first'; [[ -e "$sys/jq" ]] || { echo 'FAIL: jq not installed' >&2; exit 1; }
log="$(cat "$tmp/pacman.log")"; need "$log" 'S --noconfirm --needed jq'; need "$log" 'Syu --noconfirm --needed jdk21-openjdk'
[[ "$(grep -n 'S --noconfirm --needed jq' "$tmp/pacman.log" | head -1 | cut -d: -f1)" -lt "$(grep -n '^Syu' "$tmp/pacman.log" | head -1 | cut -d: -f1)" ]] || { echo 'FAIL: jq was not installed before the other packages' >&2; exit 1; }
ln -sf "$REALJQ" "$sys/jq"
echo 'bootstrap manifest tests passed'

# ---- A rate-limited "mvm install" (GitHub 403) is retried; persistent failure is reported ----
reset_mocks; MOCK_INSTALLED="jdk21-openjdk git curl unzip rustup base-devel jq"
mock sudo 'exit 9'; mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'
mock curl 'url=""; out=""; while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2 ;; http*) url="$1"; shift ;; *) shift ;; esac; done
case "$url" in *matchbox-quick-installer*) printf "%s\n" "$MVM_FAKE" > "$out" ;; *install-bvm*) printf "%s\n" "$BVM_FAKE" > "$out" ;; *nvm-sh/nvm*) printf "%s\n" "$NVM_FAKE" > "$out" ;; *version-latest.properties*) printf "version=1.19.0+1\n" ;; *) exit 22 ;; esac'
# mvm whose "install" fails the first N times, counted in a file; "use" and "--version" behave.
FLAKY_MVM='mkdir -p "$HOME/.mvm/bin"
cat > "$HOME/.mvm/bin/mvm" <<"M"
#!/usr/bin/env bash
case "$1" in
  install) n=$(cat "$HOME/mvm-tries" 2>/dev/null || echo 0); echo $((n+1)) > "$HOME/mvm-tries"; [[ $n -ge ${MVM_FAIL_TIMES:-2} ]] || { echo "GitHub request failed with HTTP 403" >&2; exit 1; } ;;
  use) printf "#!/usr/bin/env bash\necho \"MatchBox %s\"\n" "$2" > "$HOME/.mvm/bin/matchbox"; chmod +x "$HOME/.mvm/bin/matchbox" ;;
  --version) echo "MVM version: 2.0.1" ;;
esac
M
chmod +x "$HOME/.mvm/bin/mvm"'
fresh_home
out="$(MVM_FAKE="$FLAKY_MVM" trun env BXCACHY_RETRY_WAITS="0 0 0" MVM_FAIL_TIMES=2 bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)"
need "$out" 'MatchBox 0.12.0 installed and verified.'; [[ "$(cat "$home/mvm-tries")" == 3 ]] || { echo 'FAIL: expected exactly 3 install attempts' >&2; exit 1; }
fresh_home
if out="$(MVM_FAKE="$FLAKY_MVM" trun env BXCACHY_RETRY_WAITS="0 0 0" MVM_FAIL_TIMES=9 bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)"; then echo 'FAIL: persistent failure treated as success' >&2; exit 1; fi
need "$out" 'Failed after 3 attempts'; need "$out" 'HTTP 403'
echo 'bootstrap retry tests passed'

# ---- MatchBox from the published bxcachy-branch build (box.json "downloads"): download, sha256, no mvm ----
jq '.toolchain.matchbox = { "version": "0.13.0", "downloads": "https://downloads.example.test/bxcachy/matchbox" }' "$repo/box.json" > "$tmp/box-dl.json"
MB_BIN='#!/usr/bin/env bash
[[ "$1" == --version ]] && echo "matchbox version 0.13.0" || echo "matchbox"'
printf '%s\n' "$MB_BIN" > "$tmp/mb-good"; chmod 755 "$tmp/mb-good"
GOOD_SUM="$(sha256sum "$tmp/mb-good" | awk '{print $1}')"
reset_mocks; MOCK_INSTALLED="jdk21-openjdk git curl unzip rustup base-devel jq"
mock sudo 'exit 9'; mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'
mock curl 'url=""; out=""; while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2 ;; http*) url="$1"; shift ;; *) shift ;; esac; done
[[ -n "$out" ]] && echo "$url" >> "$CURL_LOG"
[[ "${MOCK_CURL_FAIL:-0}" == 1 ]] && exit 22
case "$url" in
  *bxcachy/matchbox/matchbox-linux-x86_64.sha256) echo "${MB_SUM:-$GOOD_SUM}  matchbox-linux-x86_64" > "$out" ;;
  *bxcachy/matchbox/matchbox-linux-x86_64) cat "$MB_FILE" > "$out" ;;
  *matchbox-quick-installer*) printf "%s\n" "$MVM_FAKE" > "$out" ;;
  *install-bvm*) printf "%s\n" "$BVM_FAKE" > "$out" ;; *nvm-sh/nvm*) printf "%s\n" "$NVM_FAKE" > "$out" ;;
  *version-latest.properties*) printf "version=1.19.0+1\n" ;;
  *) exit 22 ;;
esac'
drun() { env -i MVM_FAKE="$MVM_FAKE" NVM_FAKE="$NVM_FAKE" HOME="$home" PATH="$bin:$sys" BXCACHY_SKIP_NETWORK=1 BXCACHY_OS_RELEASE="$tmp/os-arch" MOCK_INSTALLED="$MOCK_INSTALLED" CURL_LOG="$tmp/curl.log" BVM_FAKE="$BVM_FAKE" MB_FILE="$tmp/mb-good" GOOD_SUM="$GOOD_SUM" MB_SUM="${MB_SUM:-$GOOD_SUM}" MOCK_UID="${MOCK_UID:-1000}" BXCACHY_MANIFEST="$tmp/box-dl.json" "$@"; }
fresh_home
plan="$(drun bash "$repo/bootstrap/install.sh" --plan)"
need "$plan" 'download https://downloads.example.test/bxcachy/matchbox/matchbox-linux-x86_64 and check its sha256'; refuse "$plan" 'mvm install'
need "$plan" 'download and run https://raw.githubusercontent.com/ortus-boxlang/matchbox-quick-installer'   # mvm is always installed
# install: downloaded, verified, kept under ~/.local/share/bxcachy/matchbox; mvm is installed too but does not manage this MatchBox
out="$(drun bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)"
need "$out" 'MatchBox 0.13.0 installed and verified.'
[[ -x "$home/.local/share/bxcachy/matchbox/bin/matchbox" && -x "$home/.mvm/bin/mvm" ]] || { echo 'FAIL: MatchBox not under the bxcachy home, or mvm missing' >&2; exit 1; }
[[ ! -e "$home/.mvm/bin/matchbox" ]] || { echo 'FAIL: mvm installed a MatchBox of its own' >&2; exit 1; }
need "$(cat "$tmp/curl.log")" 'bxcachy/matchbox/matchbox-linux-x86_64.sha256'; need "$(cat "$tmp/curl.log")" 'matchbox-quick-installer'
# a second run changes nothing
: > "$tmp/curl.log"; drun bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null >/dev/null 2>&1
refuse "$(cat "$tmp/curl.log")" 'matchbox-linux-x86_64'
chk="$(drun bash "$repo/bootstrap/install.sh" --check)"; need "$chk" 'matchbox: 0.13.0'
# the immutable per-build folder named in version-latest.properties is preferred over the (CDN-cached) evergreen file
mock curl 'url=""; out=""; while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2 ;; http*) url="$1"; shift ;; *) shift ;; esac; done
[[ -n "$out" ]] && echo "$url" >> "$CURL_LOG"
case "$url" in
  *bxcachy/matchbox/version-latest.properties) printf "version=0.13.0\ncommit=abc1234\n" ;;
  *bxcachy/matchbox/0.13.0-abc1234/matchbox-linux-x86_64.sha256) echo "$GOOD_SUM  matchbox-linux-x86_64" > "$out" ;;
  *bxcachy/matchbox/0.13.0-abc1234/matchbox-linux-x86_64) cat "$MB_FILE" > "$out" ;;
  *bxcachy/matchbox/matchbox-linux-x86_64*) echo "stale evergreen file must not be used" >&2; exit 22 ;;
  *matchbox-quick-installer*) printf "%s\n" "$MVM_FAKE" > "$out" ;;
  *install-bvm*) printf "%s\n" "$BVM_FAKE" > "$out" ;; *nvm-sh/nvm*) printf "%s\n" "$NVM_FAKE" > "$out" ;;
  *version-latest.properties*) printf "version=1.19.0+1\n" ;;
  *) exit 22 ;;
esac'
fresh_home; : > "$tmp/curl.log"
out="$(drun bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)" || { echo "FAIL: versioned folder download: $out" >&2; exit 1; }
need "$out" 'MatchBox 0.13.0 installed and verified.'; need "$(cat "$tmp/curl.log")" '0.13.0-abc1234/matchbox-linux-x86_64'; refuse "$(cat "$tmp/curl.log")" 'bxcachy/matchbox/matchbox-linux-x86_64'
# restore the evergreen-only mock for the tests below
mock curl 'url=""; out=""; while [[ $# -gt 0 ]]; do case "$1" in -o) out="$2"; shift 2 ;; http*) url="$1"; shift ;; *) shift ;; esac; done
[[ -n "$out" ]] && echo "$url" >> "$CURL_LOG"
[[ "${MOCK_CURL_FAIL:-0}" == 1 ]] && exit 22
case "$url" in
  *bxcachy/matchbox/matchbox-linux-x86_64.sha256) echo "${MB_SUM:-$GOOD_SUM}  matchbox-linux-x86_64" > "$out" ;;
  *bxcachy/matchbox/matchbox-linux-x86_64) cat "$MB_FILE" > "$out" ;;
  *matchbox-quick-installer*) printf "%s\n" "$MVM_FAKE" > "$out" ;;
  *install-bvm*) printf "%s\n" "$BVM_FAKE" > "$out" ;; *nvm-sh/nvm*) printf "%s\n" "$NVM_FAKE" > "$out" ;;
  *version-latest.properties*) printf "version=1.19.0+1\n" ;;
  *) exit 22 ;;
esac'
# a checksum mismatch installs nothing
fresh_home; : > "$tmp/curl.log"
if out="$(MB_SUM=deadbeef drun bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)"; then echo 'FAIL: checksum mismatch accepted' >&2; exit 1; fi
need "$out" 'checksum mismatch'; [[ ! -e "$home/.local/share/bxcachy/matchbox/bin/matchbox" ]] || { echo 'FAIL: unverified MatchBox was installed' >&2; exit 1; }
# a download that does not run installs nothing
printf '#!/usr/bin/env bash\nexit 3\n' > "$tmp/mb-broken"; chmod 755 "$tmp/mb-broken"; fresh_home
if out="$(MB_SUM="$(sha256sum "$tmp/mb-broken" | awk '{print $1}')" drun env MB_FILE="$tmp/mb-broken" bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)"; then echo 'FAIL: broken MatchBox accepted' >&2; exit 1; fi
need "$out" 'does not run'
# a local build (CI) is installed without any download
fresh_home; : > "$tmp/curl.log"
out="$(drun env BXCACHY_MATCHBOX_FILE="$tmp/mb-good" bash "$repo/bootstrap/install.sh" --install-toolchains --yes </dev/null 2>&1)"
need "$out" 'MatchBox 0.13.0 installed and verified.'; refuse "$(cat "$tmp/curl.log")" 'matchbox-linux-x86_64'
echo 'bootstrap matchbox download tests passed'

# ---- --all: every stage in order, flags forwarded, stops at the first failing stage ----
mkdir -p "$tmp/all/bin"
printf '#!/usr/bin/env bash\nif [[ "$1" == -u ]]; then echo 1000; else /usr/bin/id "$@"; fi\n' > "$tmp/all/bin/id"; chmod +x "$tmp/all/bin/id"
cat > "$tmp/all/stage.sh" <<'STAGE'
#!/usr/bin/env bash
echo "$*" >> "$ALL_LOG"
[[ "${ALL_FAIL:-}" == "$1" ]] && exit 7
exit 0
STAGE
: > "$tmp/all/log"
out="$(env PATH="$tmp/all/bin:$PATH" ALL_LOG="$tmp/all/log" BXCACHY_ALL_SCRIPT="$tmp/all/stage.sh" bash "$root/bootstrap/install.sh" --all --yes 2>&1)"
[[ "$(paste -sd'|' "$tmp/all/log")" == '--install --yes|--install-toolchains --yes|--install-binary --yes' ]] || { echo "FAIL: --all stage order or flags: $(paste -sd'|' "$tmp/all/log")" >&2; exit 1; }
: > "$tmp/all/log"
if env PATH="$tmp/all/bin:$PATH" ALL_FAIL=--install-toolchains ALL_LOG="$tmp/all/log" BXCACHY_ALL_SCRIPT="$tmp/all/stage.sh" bash "$root/bootstrap/install.sh" --all --yes >/dev/null 2>&1; then echo 'FAIL: --all ignored a failing stage' >&2; exit 1; fi
[[ "$(wc -l < "$tmp/all/log")" == 2 ]] || { echo 'FAIL: --all went on after a failing stage' >&2; exit 1; }
if bash "$root/bootstrap/install.sh" --all >/dev/null 2>&1; then echo 'FAIL: --all without --yes accepted' >&2; exit 1; fi
echo 'bootstrap --all tests passed'

# ---- nvm and Node.js are toolchain steps: nvm missing, then Node missing ----
reset_mocks; MOCK_INSTALLED="jdk21-openjdk git curl unzip rustup base-devel jq"
mock java 'echo "openjdk version \"21.0.13\" 2026-04-21" >&2'; mock mvm 'echo "MVM version: 2.0.1"'; mock matchbox 'echo "MatchBox 0.12.0"'
mock bvm 'echo "bvm 1.40.0"'; mock boxlang 'echo "Ortus BoxLang v1.19.0+67"'; mock rustc 'echo "rustc 1.90.0"'; mock rustup 'exit 0'; mock yay 'exit 0'
mock bxcachy '[[ "$1" == version ]] && echo "BxCachy 0.11.0-dev"'
rm -rf "$home"; mkdir -p "$home/.local/bin"; cp "$bin/bxcachy" "$home/.local/bin/bxcachy"; rm "$bin/bxcachy"
nplan() { env -i HOME="$home" PATH="$home/.local/bin:$bin:$sys" BXCACHY_SKIP_NETWORK=1 BXCACHY_OS_RELEASE="$tmp/os-arch" MOCK_INSTALLED="$MOCK_INSTALLED" bash "$repo/bootstrap/install.sh" "$@"; }
plan="$(nplan --plan)"
need "$plan" 'download and run https://raw.githubusercontent.com/nvm-sh/nvm/v0.41.0/install.sh'; need "$plan" 'nvm install lts/*'
need "$(nplan --check)" 'nvm: missing'
mkdir -p "$home/.nvm"; printf '%s\n' 'nvm() { case "$1" in --version) echo 0.41.0 ;; esac; }' 'true' > "$home/.nvm/nvm.sh"
plan="$(nplan --plan)"; refuse "$plan" 'nvm-sh/nvm'; need "$plan" 'nvm install lts/*'
need "$(nplan --check)" 'node: missing'
echo 'bootstrap nvm tests passed'

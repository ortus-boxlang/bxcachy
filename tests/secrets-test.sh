#!/usr/bin/env bash
# `bxrig secrets` with a fake secret-tool and busctl (keyring backend) and with private files. Usage: secrets-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/nobin" "$tmp/kr"
# fake secret-tool: store (secret on stdin), lookup, clear, search --all; attributes are "service bxrig name NAME"
cat > "$tmp/bin/secret-tool" <<'SH'
#!/usr/bin/env bash
kr="${FAKE_KEYRING:?}"
cmd="$1"; shift
[[ "$cmd" == store ]] && shift   # --label=...
[[ "$cmd" == search ]] && shift   # --all
name=""; while [[ $# -gt 0 ]]; do [[ "$1" == name ]] && name="$2"; shift 2 || break; done
case "$cmd" in
  store) cat > "$kr/$name" ;;
  lookup) [[ -f "$kr/$name" ]] && { cat "$kr/$name"; exit 0; } || exit 1 ;;
  clear) rm -f "$kr/$name" ;;
  search) for f in "$kr"/*; do [[ -f "$f" ]] || continue; printf '[/x]\nlabel = BxRig\nsecret = %s\nattribute.service = bxrig\nattribute.name = %s\n\n' "$(cat "$f")" "$(basename "$f")"; done ;;
esac
SH
printf '#!/usr/bin/env bash\necho "org.freedesktop.secrets  123 kwalletd6"\n' > "$tmp/bin/busctl"
chmod +x "$tmp/bin/secret-tool" "$tmp/bin/busctl"
ln -sf "$(command -v sh)" "$tmp/nobin/sh"
for c in grep cat chmod mkdir rm printf stty; do ln -sf "$(command -v $c)" "$tmp/nobin/$c"; done
export FAKE_KEYRING="$tmp/kr"
run() { env -u GEMINI_API_KEY -u OPENAI_API_KEY -u ANTHROPIC_API_KEY -u GITHUB_TOKEN -u NOVITA_API_KEY -u MY_LLM_KEY HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_STATE_HOME="$tmp/state" BXRIG_DATA_HOME="$tmp/data" FAKE_KEYRING="$FAKE_KEYRING" PATH="$tmp/bin:$PATH" "$@"; }
runfile() { env -u GEMINI_API_KEY -u OPENAI_API_KEY -u ANTHROPIC_API_KEY -u GITHUB_TOKEN -u NOVITA_API_KEY -u MY_LLM_KEY HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg2" BXRIG_STATE_HOME="$tmp/state" BXRIG_DATA_HOME="$tmp/data2" PATH="$tmp/nobin" "$@"; }
code() { set +e; "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
s() { run "$binary" secrets "$@"; }

# status: keyring is detected first and is the default
s status --json | jq -e '.data.backend == "keyring" and .data.keyring_available == true' >/dev/null || fail 'keyring should be the default when present'

# set: typed value comes from the (fake) terminal file, never from arguments
printf 'sk-test-123\n' > "$tmp/tty"
BXRIG_TTY_IN="$tmp/tty" s set ANTHROPIC_API_KEY | grep -q 'was saved (keyring)' || fail 'set via prompt'
[[ "$(cat "$tmp/kr/ANTHROPIC_API_KEY")" == 'sk-test-123' ]] || fail "the keyring got the value: $(cat "$tmp/kr/ANTHROPIC_API_KEY")"
[[ "$(code "$binary" secrets set lower_case)" == 4 ]] || fail 'a bad name exits 4'
printf '' > "$tmp/tty"; [[ "$(BXRIG_TTY_IN="$tmp/tty" code env -u GEMINI_API_KEY -u OPENAI_API_KEY -u ANTHROPIC_API_KEY -u GITHUB_TOKEN -u NOVITA_API_KEY -u MY_LLM_KEY HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" FAKE_KEYRING="$FAKE_KEYRING" PATH="$tmp/bin:$PATH" BXRIG_TTY_IN="$tmp/tty" "$binary" secrets set OPENAI_API_KEY)" == 4 ]] || fail 'an empty value exits 4'
printf 'oa-key\n' > "$tmp/valfile"
s set OPENAI_API_KEY --from-file="$tmp/valfile" | grep -q 'was saved' || fail 'set --from-file'
printf 'oa-key2\n' > "$tmp/valfile"
s set OPENAI_API_KEY --from-file="$tmp/valfile" | grep -q 'was replaced' || fail 'a second set replaces'

# list, get
s list | grep -q 'ANTHROPIC_API_KEY .*ai .*(claude-code, opencode-cli)' || fail "list shows names, type and the agents that use them: $(s list)"
[[ "$(s list)" != *sk-test-123* ]] || fail 'list must never print values'
s get ANTHROPIC_API_KEY | grep -q 'is set (11 characters)' || fail 'get hides the value'
[[ "$(s get ANTHROPIC_API_KEY)" != *sk-test-123* ]] || fail 'get printed the value without --show'
[[ "$(s get ANTHROPIC_API_KEY --show)" == 'sk-test-123' ]] || fail 'get --show prints the value'
s get ANTHROPIC_API_KEY --json | jq -e '.data.length == 11 and (.data | has("value") | not)' >/dev/null || fail 'get --json hides the value'
[[ "$(code env -u GEMINI_API_KEY -u OPENAI_API_KEY -u ANTHROPIC_API_KEY -u GITHUB_TOKEN -u NOVITA_API_KEY -u MY_LLM_KEY HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" FAKE_KEYRING="$FAKE_KEYRING" PATH="$tmp/bin:$PATH" "$binary" secrets get GEMINI_API_KEY)" == 4 ]] || fail 'a missing secret exits 4'

# env: export lines, quotes escaped
printf "a'b\n" > "$tmp/valfile"; s set QUOTE_TEST --from-file="$tmp/valfile" >/dev/null
out="$(s env QUOTE_TEST)"; [[ "$out" == "export QUOTE_TEST='a'\\''b'" ]] || fail "env quoting: $out"
[[ "$(eval "$out"; echo "$QUOTE_TEST")" == "a'b" ]] || fail 'env output must round-trip through eval'
[[ "$(s env ANTHROPIC_API_KEY GEMINI_API_KEY)" == "export ANTHROPIC_API_KEY='sk-test-123'" ]] || fail 'env skips names that are not set'

# run: the program gets the secret, its flags are its own, its exit code comes back, a missing secret is skipped (or --strict stops)
r="$(s run ANTHROPIC_API_KEY -- sh -c 'echo "$ANTHROPIC_API_KEY"')"; [[ "$r" == 'sk-test-123' ]] || fail "run passes the env: $r"
r="$(s run ANTHROPIC_API_KEY -- printf '%s' --resume)"; [[ "$r" == '--resume' ]] || fail "flags after -- belong to the program: $r"
[[ "$(code env -u GEMINI_API_KEY -u OPENAI_API_KEY -u ANTHROPIC_API_KEY -u GITHUB_TOKEN -u NOVITA_API_KEY -u MY_LLM_KEY HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" FAKE_KEYRING="$FAKE_KEYRING" PATH="$tmp/bin:$PATH" "$binary" secrets run ANTHROPIC_API_KEY -- sh -c 'exit 7')" == 7 ]] || fail 'run returns the program exit code'
r="$(s run GEMINI_API_KEY -- sh -c 'echo "[${GEMINI_API_KEY:-none}]"')"; [[ "$r" == '[none]' ]] || fail 'a missing secret is skipped'
[[ "$(code env -u GEMINI_API_KEY -u OPENAI_API_KEY -u ANTHROPIC_API_KEY -u GITHUB_TOKEN -u NOVITA_API_KEY -u MY_LLM_KEY HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" FAKE_KEYRING="$FAKE_KEYRING" PATH="$tmp/bin:$PATH" "$binary" secrets run GEMINI_API_KEY --strict -- true)" == 4 ]] || fail '--strict with a missing secret exits 4'


# loaders: wrappers for the agents whose key is stored; they hold no values
sh="$tmp/cfg/bxrig/secrets.sh"; fish="$tmp/cfg/bxrig/secrets.fish"
[[ -f "$sh" && -f "$fish" ]] || fail 'set writes the loader files'
grep -q '^claude() { bxrig secrets run ANTHROPIC_API_KEY -- command claude "\$@"; }$' "$sh" || fail "claude wrapper (sh): $(cat "$sh")"
grep -q '^codex() { bxrig secrets run OPENAI_API_KEY' "$sh" || fail 'codex wrapper'
! grep -q '^gemini()' "$sh" || fail 'no wrapper without a stored key'
grep -q 'function claude' "$fish" && grep -q 'command claude \$argv' "$fish" || fail 'claude wrapper (fish)'
! grep -rq 'sk-test-123' "$tmp/cfg" || fail 'a loader file holds a value'
s apply --json | jq -e '.exit_code == 2' >/dev/null 2>&1 || [[ "$(code env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" FAKE_KEYRING="$FAKE_KEYRING" PATH="$tmp/bin:$PATH" "$binary" secrets apply)" == 2 ]] || fail 'apply without --yes exits 2'
s apply --yes | grep -q 'Wrote' || fail 'apply --yes'
# the shell init templates source the loader (bash is enough to prove the line works)
bash -c 'cfg="$1"; XDG_CONFIG_HOME="$cfg"; [ -r "${XDG_CONFIG_HOME:-$HOME/.config}/bxrig/secrets.sh" ] && . "${XDG_CONFIG_HOME:-$HOME/.config}/bxrig/secrets.sh"; type claude | head -1' _ "$tmp/cfg" | grep -q 'claude is a function' || fail 'the loader file must define the function when sourced'

# type: provider keys are "ai" by name; others are "other" unless told; --type filters; a given type is remembered (names only)
printf 'tok\n' > "$tmp/valfile"
s set GITHUB_TOKEN --from-file="$tmp/valfile" | grep -q 'Type: other' || fail 'an unknown name is type other, with a hint'
s set NOVITA_API_KEY --from-file="$tmp/valfile" --json | jq -e '.data.type == "ai"' >/dev/null || fail 'a provider key is type ai'
s set MY_LLM_KEY --from-file="$tmp/valfile" --type=ai --provider=custom --json | jq -e '.data.type == "ai"' >/dev/null || fail '--type=ai on an unknown name'
[[ "$(code env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" FAKE_KEYRING="$FAKE_KEYRING" PATH="$tmp/bin:$PATH" "$binary" secrets set X_KEY --from-file="$tmp/valfile" --type=bogus)" == 4 ]] || fail 'a bad --type exits 4'
s list --type=ai --json | jq -e '([.data.secrets[].name] | index("NOVITA_API_KEY")) and ([.data.secrets[].name] | index("MY_LLM_KEY")) and (([.data.secrets[].name] | index("GITHUB_TOKEN")) | not)' >/dev/null || fail 'list --type=ai'
s list --type=other --json | jq -e '[.data.secrets[].name] == ["GITHUB_TOKEN"] or ([.data.secrets[].name] | index("GITHUB_TOKEN"))' >/dev/null || fail 'list --type=other'
jq -e '.meta.MY_LLM_KEY.type == "ai" and (tostring | contains("tok") | not)' "$tmp/cfg/bxrig/secrets.json" >/dev/null || fail 'secrets.json keeps type and provider, never a value'
# run --type=ai loads every AI key and no other secret
r="$(s run --type=ai -- sh -c 'echo "${NOVITA_API_KEY:-no}/${MY_LLM_KEY:-no}/${GITHUB_TOKEN:-no}"')"; [[ "$r" == 'tok/tok/no' ]] || fail "run --type=ai: $r"
# OpenCode accepts many providers: its wrapper carries every stored key it accepts, and only those
grep -q '^opencode() { bxrig secrets run ANTHROPIC_API_KEY OPENAI_API_KEY NOVITA_API_KEY -- command opencode "\$@"; }$' "$sh" || fail "opencode wrapper: $(grep opencode "$sh")"
! grep -q 'GITHUB_TOKEN\|MY_LLM_KEY' "$sh" || fail 'a wrapper must not carry keys the agent does not accept'
s unset GITHUB_TOKEN --yes >/dev/null; s unset NOVITA_API_KEY --yes >/dev/null; s unset MY_LLM_KEY --yes >/dev/null

# global export: needs --yes and prints the warning first; the cache is mode 600 in the runtime dir and holds the value, files do not
mkdir -p "$tmp/rt"; chmod 700 "$tmp/rt"
g() { run env XDG_RUNTIME_DIR="$tmp/rt" "$binary" secrets global "$@"; }
out="$(g on ANTHROPIC_API_KEY)" || true
[[ "$out" == *'every program you start'* ]] || fail "the global warning: $out"
[[ ! -e "$tmp/rt/bxrig-secrets.env" ]] || fail 'the plan wrote the cache'
g on ANTHROPIC_API_KEY --yes | grep -q 'exported to every new shell' || fail 'global on --yes'
[[ "$(stat -c %a "$tmp/rt/bxrig-secrets.env")" == 600 ]] || fail 'the cache is mode 600'
grep -q "^export ANTHROPIC_API_KEY='sk-test-123'$" "$tmp/rt/bxrig-secrets.env" || fail 'the cache holds the export line'
grep -q "^set -gx ANTHROPIC_API_KEY 'sk-test-123'$" "$tmp/rt/bxrig-secrets.fish" || fail 'the fish cache'
! grep -q '^claude()' "$sh" || fail 'a globally exported key needs no wrapper'
grep -q 'bxrig secrets unlock' "$sh" || fail 'the loader unlocks once per login'
[[ "$(env -i PATH="$PATH" XDG_RUNTIME_DIR="$tmp/rt" bash -c '. "$1"; echo "$ANTHROPIC_API_KEY"' _ "$sh")" == 'sk-test-123' ]] || fail 'a new shell gets the value from the cache'
g show | grep -q 'ANTHROPIC_API_KEY' || fail 'global show'
rm "$tmp/rt"/bxrig-secrets.*; run env XDG_RUNTIME_DIR="$tmp/rt" "$binary" secrets unlock | grep -q 'Session cache filled' || fail 'unlock'
[[ -s "$tmp/rt/bxrig-secrets.env" ]] || fail 'unlock refills the cache'
g off ANTHROPIC_API_KEY | grep -q 'back to per-command' || fail 'global off'
[[ ! -e "$tmp/rt/bxrig-secrets.env" ]] || fail 'the cache is removed when nothing is exported'
grep -q '^claude()' "$sh" || fail 'the wrapper is back after global off'

# export and import (fake age: header line + reversed text; the real age asks for a passphrase on the terminal)
cat > "$tmp/bin/age" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == -p ]]; then out="$3"; { echo "age-encryption.org/v1"; rev; } > "$out"; elif [[ "$1" == -d ]]; then tail -n +2 "$2" | rev; fi
SH
chmod +x "$tmp/bin/age"
printf 'x\n' > "$tmp/valfile"; s set EXTRA_TOKEN --from-file="$tmp/valfile" >/dev/null
rc() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
[[ "$(rc "$binary" secrets export "$tmp/out.age")" == 2 ]] || fail 'export without --yes exits 2'
[[ ! -e "$tmp/out.age" ]] || fail 'the plan wrote the export'
s export "$tmp/out.age" --yes | grep -q 'Exported 4 secret(s)' || fail "export: $(s export "$tmp/out2.age" --yes 2>&1)"
head -1 "$tmp/out.age" | grep -q '^age-encryption.org/v' || fail 'the export is an age file'
! grep -q 'sk-test-123' "$tmp/out.age" || fail 'the encrypted export shows a value'
[[ "$(rc "$binary" secrets export "$tmp/out.age" --yes)" == 4 ]] || fail 'export refuses to replace a file without --force'
s export "$tmp/plain.env" --plain --yes >/dev/null; [[ "$(stat -c %a "$tmp/plain.env")" == 600 ]] || fail 'the plain export is mode 600'
grep -q "^export ANTHROPIC_API_KEY='sk-test-123'$" "$tmp/plain.env" || fail 'the plain export holds export lines'

# import on a "new machine" (empty keyring): plan, then apply; differing values are kept unless --overwrite
rm -f "$tmp/kr"/*
[[ "$(rc "$binary" secrets import "$tmp/out.age")" == 2 ]] || fail 'import without --yes exits 2'
[[ -z "$(ls "$tmp/kr")" ]] || fail 'the import plan stored something'
s import "$tmp/out.age" --yes | grep -q 'Imported 4 secret(s)' || fail 'import (age)'
[[ "$(s get ANTHROPIC_API_KEY --show)" == 'sk-test-123' ]] || fail 'imported value round-trips'
printf 'ANTHROPIC_API_KEY="changed"\n# comment\nexport NEW_ONE=plain\nbad name=1\n' > "$tmp/in.env"
out="$(s import "$tmp/in.env" --yes)"
[[ "$out" == *'ANTHROPIC_API_KEY: differs, kept'* && "$out" == *'NEW_ONE: will be added'* && "$(s get ANTHROPIC_API_KEY --show)" == 'sk-test-123' ]] || fail "differing values are kept: $out"
s import "$tmp/in.env" --overwrite --yes >/dev/null; [[ "$(s get ANTHROPIC_API_KEY --show)" == 'changed' ]] || fail '--overwrite replaces'
[[ "$(s get NEW_ONE --show)" == 'plain' ]] || fail 'a plain .env line imports'
[[ "$(rc "$binary" secrets import "$tmp/nope")" == 4 ]] || fail 'a missing file exits 4'

# setup: no keyring on the machine -> install libsecret, age and a keyring (KWallet on Plasma, GNOME Keyring otherwise); never without --yes
mkdir -p "$tmp/sbin"; : > "$tmp/pacman.log"
printf '#!/bin/sh\necho "pacman $*" >> "$PACLOG"\n' > "$tmp/sbin/pacman"
printf '#!/bin/sh\nexec "$@"\n' > "$tmp/sbin/sudo"
printf '#!/bin/sh\nexit 1\n' > "$tmp/sbin/busctl"
chmod +x "$tmp/sbin"/*
for c in sh grep cat; do ln -sf "$(command -v $c)" "$tmp/sbin/$c"; done
su() { env XDG_CURRENT_DESKTOP="${DESK:-}" HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg3" BXRIG_DATA_HOME="$tmp/data3" PACLOG="$tmp/pacman.log" PATH="$tmp/sbin" "$@"; }
{ su "$binary" secrets setup --json || true; } | jq -e '.data.keyring_install == "gnome-keyring" and (.data.packages | index("libsecret")) and (.data.packages | index("age"))' >/dev/null || fail 'setup plan: gnome-keyring off Plasma'
[[ ! -s "$tmp/pacman.log" ]] || fail 'the setup plan ran pacman'
{ DESK=KDE su "$binary" secrets setup --json || true; } | jq -e '.data.keyring_install == "kwallet"' >/dev/null || fail 'setup plan: kwallet on Plasma'
{ su "$binary" secrets setup --keyring=none --json || true; } | jq -e '.data.file_backend == true and .data.keyring_install == ""' >/dev/null || fail 'setup --keyring=none'
rc2=0; su "$binary" secrets setup >/dev/null 2>&1 || rc2=$?; [[ "$rc2" == 2 ]] || fail "setup without --yes exits 2 (got $rc2)"
su "$binary" secrets setup --yes | grep -q 'Done' || fail 'setup --yes'
grep -q 'pacman -S --needed --noconfirm libsecret age gnome-keyring' "$tmp/pacman.log" || fail "setup installs: $(cat "$tmp/pacman.log")"
su "$binary" secrets setup --keyring=none --yes >/dev/null; [[ "$(jq -r .backend "$tmp/cfg3/bxrig/secrets.json")" == file ]] || fail '--keyring=none saves the file backend'
rc3=0; su "$binary" secrets setup --keyring=bogus >/dev/null 2>&1 || rc3=$?; [[ "$rc3" == 4 ]] || fail 'an unknown keyring exits 4'
# a keyring that is already there is kept, nothing but missing tools is installed
: > "$tmp/pacman.log"; printf '#!/bin/sh\necho "org.freedesktop.secrets 1 kwalletd6"\n' > "$tmp/sbin/busctl"; printf '#!/bin/sh\n' > "$tmp/sbin/secret-tool"; printf '#!/bin/sh\n' > "$tmp/sbin/age"; chmod +x "$tmp/sbin/busctl" "$tmp/sbin/secret-tool" "$tmp/sbin/age"
su "$binary" secrets setup --yes --json | jq -e '.data.keyring_found == true and (.data.packages | length) == 0' >/dev/null || fail 'an existing keyring and tools need no install'
[[ ! -s "$tmp/pacman.log" ]] || fail 'pacman ran although nothing was missing'

# unset: plan, then apply
[[ "$(code env -u GEMINI_API_KEY -u OPENAI_API_KEY -u ANTHROPIC_API_KEY -u GITHUB_TOKEN -u NOVITA_API_KEY -u MY_LLM_KEY HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" FAKE_KEYRING="$FAKE_KEYRING" PATH="$tmp/bin:$PATH" "$binary" secrets unset QUOTE_TEST)" == 2 ]] || fail 'unset without --yes exits 2'
[[ -f "$tmp/kr/QUOTE_TEST" ]] || fail 'the plan deleted the secret'
s unset QUOTE_TEST --yes | grep -q 'was deleted' || fail 'unset --yes'
[[ ! -f "$tmp/kr/QUOTE_TEST" ]] || fail 'unset did not delete'

# no keyring: private files, mode 600 in a mode 700 folder
runfile "$binary" secrets status --json | jq -e '.data.backend == "file" and .data.keyring_available == false' >/dev/null || fail 'no keyring means the file backend'
printf 'file-secret\n' > "$tmp/valfile"
runfile "$binary" secrets set GEMINI_API_KEY --from-file="$tmp/valfile" | grep -q 'was saved (file)' || fail 'set (file)'
[[ "$(stat -c %a "$tmp/data2/secrets/GEMINI_API_KEY")" == 600 && "$(stat -c %a "$tmp/data2/secrets")" == 700 ]] || fail 'file modes'
[[ "$(runfile "$binary" secrets get GEMINI_API_KEY --show)" == 'file-secret' ]] || fail 'get (file)'
runfile "$binary" secrets list | grep -q 'GEMINI_API_KEY .*ai .*(gemini-cli, opencode-cli)' || fail 'list (file)'
r="$(runfile "$binary" secrets run GEMINI_API_KEY -- sh -c 'echo "$GEMINI_API_KEY"')"; [[ "$r" == 'file-secret' ]] || fail "run (file): $r"
runfile "$binary" secrets unset GEMINI_API_KEY --yes >/dev/null; [[ ! -e "$tmp/data2/secrets/GEMINI_API_KEY" ]] || fail 'unset (file)'
echo "secrets-test: ok"

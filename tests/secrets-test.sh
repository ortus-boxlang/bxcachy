#!/usr/bin/env bash
# `bxcachy secrets` with a fake secret-tool and busctl (keyring backend) and with private files. Usage: secrets-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/nobin" "$tmp/kr"
# fake secret-tool: store (secret on stdin), lookup, clear, search --all; attributes are "service bxcachy name NAME"
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
  search) for f in "$kr"/*; do [[ -f "$f" ]] || continue; printf '[/x]\nlabel = BxCachy\nsecret = %s\nattribute.service = bxcachy\nattribute.name = %s\n\n' "$(cat "$f")" "$(basename "$f")"; done ;;
esac
SH
printf '#!/usr/bin/env bash\necho "org.freedesktop.secrets  123 kwalletd6"\n' > "$tmp/bin/busctl"
chmod +x "$tmp/bin/secret-tool" "$tmp/bin/busctl"
ln -sf "$(command -v sh)" "$tmp/nobin/sh"
for c in grep cat chmod mkdir rm printf stty; do ln -sf "$(command -v $c)" "$tmp/nobin/$c"; done
export FAKE_KEYRING="$tmp/kr"
run() { env -u GEMINI_API_KEY -u OPENAI_API_KEY -u ANTHROPIC_API_KEY HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_STATE_HOME="$tmp/state" BXCACHY_DATA_HOME="$tmp/data" FAKE_KEYRING="$FAKE_KEYRING" PATH="$tmp/bin:$PATH" "$@"; }
runfile() { env -u GEMINI_API_KEY -u OPENAI_API_KEY -u ANTHROPIC_API_KEY HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg2" BXCACHY_STATE_HOME="$tmp/state" BXCACHY_DATA_HOME="$tmp/data2" PATH="$tmp/nobin" "$@"; }
code() { set +e; "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
s() { run "$binary" secrets "$@"; }

# status: keyring is detected first and is the default
s status --json | jq -e '.data.backend == "keyring" and .data.keyring_available == true' >/dev/null || fail 'keyring should be the default when present'

# set: typed value comes from the (fake) terminal file, never from arguments
printf 'sk-test-123\n' > "$tmp/tty"
BXCACHY_TTY_IN="$tmp/tty" s set ANTHROPIC_API_KEY | grep -q 'was saved (keyring)' || fail 'set via prompt'
[[ "$(cat "$tmp/kr/ANTHROPIC_API_KEY")" == 'sk-test-123' ]] || fail "the keyring got the value: $(cat "$tmp/kr/ANTHROPIC_API_KEY")"
[[ "$(code "$binary" secrets set lower_case)" == 4 ]] || fail 'a bad name exits 4'
printf '' > "$tmp/tty"; [[ "$(BXCACHY_TTY_IN="$tmp/tty" code env -u GEMINI_API_KEY -u OPENAI_API_KEY -u ANTHROPIC_API_KEY HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" FAKE_KEYRING="$FAKE_KEYRING" PATH="$tmp/bin:$PATH" BXCACHY_TTY_IN="$tmp/tty" "$binary" secrets set OPENAI_API_KEY)" == 4 ]] || fail 'an empty value exits 4'
printf 'oa-key\n' > "$tmp/valfile"
s set OPENAI_API_KEY --from-file="$tmp/valfile" | grep -q 'was saved' || fail 'set --from-file'
printf 'oa-key2\n' > "$tmp/valfile"
s set OPENAI_API_KEY --from-file="$tmp/valfile" | grep -q 'was replaced' || fail 'a second set replaces'

# list, get
s list | grep -q 'ANTHROPIC_API_KEY  (claude-code)' || fail 'list shows names and the agent that uses them'
[[ "$(s list)" != *sk-test-123* ]] || fail 'list must never print values'
s get ANTHROPIC_API_KEY | grep -q 'is set (11 characters)' || fail 'get hides the value'
[[ "$(s get ANTHROPIC_API_KEY)" != *sk-test-123* ]] || fail 'get printed the value without --show'
[[ "$(s get ANTHROPIC_API_KEY --show)" == 'sk-test-123' ]] || fail 'get --show prints the value'
s get ANTHROPIC_API_KEY --json | jq -e '.data.length == 11 and (.data | has("value") | not)' >/dev/null || fail 'get --json hides the value'
[[ "$(code env -u GEMINI_API_KEY -u OPENAI_API_KEY -u ANTHROPIC_API_KEY HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" FAKE_KEYRING="$FAKE_KEYRING" PATH="$tmp/bin:$PATH" "$binary" secrets get GEMINI_API_KEY)" == 4 ]] || fail 'a missing secret exits 4'

# env: export lines, quotes escaped
printf "a'b\n" > "$tmp/valfile"; s set QUOTE_TEST --from-file="$tmp/valfile" >/dev/null
out="$(s env QUOTE_TEST)"; [[ "$out" == "export QUOTE_TEST='a'\\''b'" ]] || fail "env quoting: $out"
[[ "$(eval "$out"; echo "$QUOTE_TEST")" == "a'b" ]] || fail 'env output must round-trip through eval'
[[ "$(s env ANTHROPIC_API_KEY GEMINI_API_KEY)" == "export ANTHROPIC_API_KEY='sk-test-123'" ]] || fail 'env skips names that are not set'

# run: the program gets the secret, its flags are its own, its exit code comes back, a missing secret is skipped (or --strict stops)
r="$(s run ANTHROPIC_API_KEY -- sh -c 'echo "$ANTHROPIC_API_KEY"')"; [[ "$r" == 'sk-test-123' ]] || fail "run passes the env: $r"
r="$(s run ANTHROPIC_API_KEY -- printf '%s' --resume)"; [[ "$r" == '--resume' ]] || fail "flags after -- belong to the program: $r"
[[ "$(code env -u GEMINI_API_KEY -u OPENAI_API_KEY -u ANTHROPIC_API_KEY HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" FAKE_KEYRING="$FAKE_KEYRING" PATH="$tmp/bin:$PATH" "$binary" secrets run ANTHROPIC_API_KEY -- sh -c 'exit 7')" == 7 ]] || fail 'run returns the program exit code'
r="$(s run GEMINI_API_KEY -- sh -c 'echo "[${GEMINI_API_KEY:-none}]"')"; [[ "$r" == '[none]' ]] || fail 'a missing secret is skipped'
[[ "$(code env -u GEMINI_API_KEY -u OPENAI_API_KEY -u ANTHROPIC_API_KEY HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" FAKE_KEYRING="$FAKE_KEYRING" PATH="$tmp/bin:$PATH" "$binary" secrets run GEMINI_API_KEY --strict -- true)" == 4 ]] || fail '--strict with a missing secret exits 4'

# unset: plan, then apply
[[ "$(code env -u GEMINI_API_KEY -u OPENAI_API_KEY -u ANTHROPIC_API_KEY HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" FAKE_KEYRING="$FAKE_KEYRING" PATH="$tmp/bin:$PATH" "$binary" secrets unset QUOTE_TEST)" == 2 ]] || fail 'unset without --yes exits 2'
[[ -f "$tmp/kr/QUOTE_TEST" ]] || fail 'the plan deleted the secret'
s unset QUOTE_TEST --yes | grep -q 'was deleted' || fail 'unset --yes'
[[ ! -f "$tmp/kr/QUOTE_TEST" ]] || fail 'unset did not delete'

# no keyring: private files, mode 600 in a mode 700 folder
runfile "$binary" secrets status --json | jq -e '.data.backend == "file" and .data.keyring_available == false' >/dev/null || fail 'no keyring means the file backend'
printf 'file-secret\n' > "$tmp/valfile"
runfile "$binary" secrets set GEMINI_API_KEY --from-file="$tmp/valfile" | grep -q 'was saved (file)' || fail 'set (file)'
[[ "$(stat -c %a "$tmp/data2/secrets/GEMINI_API_KEY")" == 600 && "$(stat -c %a "$tmp/data2/secrets")" == 700 ]] || fail 'file modes'
[[ "$(runfile "$binary" secrets get GEMINI_API_KEY --show)" == 'file-secret' ]] || fail 'get (file)'
runfile "$binary" secrets list | grep -q 'GEMINI_API_KEY  (gemini-cli)' || fail 'list (file)'
r="$(runfile "$binary" secrets run GEMINI_API_KEY -- sh -c 'echo "$GEMINI_API_KEY"')"; [[ "$r" == 'file-secret' ]] || fail "run (file): $r"
runfile "$binary" secrets unset GEMINI_API_KEY --yes >/dev/null; [[ ! -e "$tmp/data2/secrets/GEMINI_API_KEY" ]] || fail 'unset (file)'
echo "secrets-test: ok"

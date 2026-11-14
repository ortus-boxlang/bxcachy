#!/usr/bin/env bash
# `bxrig mail` end to end with a fake, stateful podman/docker and a tiny fake of the Mailpit API on 127.0.0.1. Usage: mail-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; srv=""; trap '[[ -n "$srv" ]] && kill "$srv" 2>/dev/null; rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/fake" "$tmp/nobin"
# fake container engine: one folder per container, every call logged to $FAKE/<program>.log
cat > "$tmp/bin/fakeengine" <<'FAKE'
#!/usr/bin/env bash
prog="$(basename "$0")"; db="${FAKE:?}/containers"; mkdir -p "$db"
echo "$*" >> "$FAKE/$prog.log"
case "$1" in
  --version) echo "$prog version 5.0" ;;
  container) name="${@: -1}"; [[ -d "$db/$name" ]] || exit 1
    if [[ "$3" == --format ]]; then cat "$db/$name/state"; fi ;;
  run) [[ -z "${FAKE_FAIL:-}" ]] || { echo "boom: image pull failed"; exit 125; }
    name=""; for ((i=1;i<=$#;i++)); do [[ "${!i}" == --name ]] && { j=$((i+1)); name="${!j}"; }; done
    mkdir -p "$db/$name"; echo running > "$db/$name/state"; echo "$*" > "$db/$name/run"; echo "abc123" ;;
  start) echo running > "$db/$2/state" ;;
  stop) target="${2:?}"; if grep -q -- '--rm' "$db/$target/run"; then rm -rf "${db:?}/${target:?}"; else echo exited > "$db/$target/state"; fi ;;
  rm) target="${@: -1}"; rm -rf "${db:?}/${target:?}" ;;
  *) exit 9 ;;
esac
FAKE
chmod +x "$tmp/bin/fakeengine"; ln -s fakeengine "$tmp/bin/podman"; ln -s fakeengine "$tmp/bin/docker"
# fake Mailpit API (the paths and fields of its swagger)
cat > "$tmp/api.py" <<'PY'
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
state = {"msgs": [
  {"ID": "AAAA1111", "From": {"Name": "Shop", "Address": "shop@example.test"}, "To": [{"Name": "", "Address": "you@example.test"}], "Subject": "Order shipped", "Created": "2026-11-14T09:42:10.123Z", "Size": 2048, "Attachments": 0, "Read": False, "Snippet": "Your order"},
  {"ID": "BBBB2222", "From": {"Name": "", "Address": "billing@example.test"}, "To": [{"Name": "", "Address": "you@example.test"}], "Subject": "Invoice", "Created": "2026-11-14T09:12:55Z", "Size": 90112, "Attachments": 1, "Read": True, "Snippet": "Invoice"}]}
full = {"AAAA1111": {"ID": "AAAA1111", "From": {"Name": "Shop", "Address": "shop@example.test"}, "To": [{"Name": "", "Address": "you@example.test"}], "Cc": [], "Bcc": [], "Subject": "Order shipped", "Date": "2026-11-14T09:42:10Z", "Text": "Hello\nYour order is on its way.", "HTML": "<p>Hello</p>", "Attachments": []},
        "BBBB2222": {"ID": "BBBB2222", "From": {"Name": "", "Address": "billing@example.test"}, "To": [{"Name": "", "Address": "you@example.test"}], "Cc": [], "Bcc": [], "Subject": "Invoice", "Date": "2026-11-14T09:12:55Z", "Text": "", "HTML": "<p>Invoice</p>", "Attachments": [{"FileName": "invoice.pdf", "ContentType": "application/pdf", "Size": 88000, "PartID": "2"}]}}
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def send(self, code, obj=None):
        body = json.dumps(obj if obj is not None else {}).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json"); self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
    def do_GET(self):
        if self.path.startswith("/api/v1/messages"):
            return self.send(200, {"total": len(state["msgs"]), "unread": sum(1 for m in state["msgs"] if not m["Read"]), "messages_count": len(state["msgs"]), "messages": state["msgs"], "start": 0, "tags": []})
        if self.path.startswith("/api/v1/message/"):
            i = self.path.split("/")[4].split("?")[0]
            return self.send(200, full[i]) if i in full and any(m["ID"] == i for m in state["msgs"]) else self.send(404, {"Error": "not found"})
        self.send(404, {})
    def do_DELETE(self):
        n = int(self.headers.get("Content-Length") or 0); body = json.loads(self.rfile.read(n) or b"{}")
        ids = body.get("IDs")
        state["msgs"] = [m for m in state["msgs"] if ids is not None and m["ID"] not in ids]
        self.send(200, "ok")
    def do_POST(self):
        n = int(self.headers.get("Content-Length") or 0); body = json.loads(self.rfile.read(n) or b"{}")
        if self.path == "/api/v1/send":
            open(sys.argv[1], "w").write(json.dumps(body))
            state["msgs"].insert(0, {"ID": "CCCC3333", "From": {"Name": body["From"].get("Name", ""), "Address": body["From"]["Email"]}, "To": [{"Name": "", "Address": body["To"][0]["Email"]}], "Subject": body["Subject"], "Created": "2026-11-14T10:00:00Z", "Size": 500, "Attachments": 0, "Read": False, "Snippet": ""})
            full["CCCC3333"] = {"ID": "CCCC3333", "From": {"Name": "BxRig", "Address": "bxrig@localhost"}, "To": [{"Name": "", "Address": body["To"][0]["Email"]}], "Cc": [], "Bcc": [], "Subject": body["Subject"], "Date": "2026-11-14T10:00:00Z", "Text": body.get("Text", ""), "HTML": "", "Attachments": []}
            return self.send(200, {"ID": "CCCC3333"})
        self.send(404, {})
s = HTTPServer(("127.0.0.1", 0), H); print(s.server_address[1], flush=True); s.serve_forever()
PY
export FAKE="$tmp/fake"
run() { env BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_DATA_HOME="$tmp/data" HOME="$tmp/home" PATH="$tmp/bin:$PATH" FAKE="$FAKE" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
c=bxrig-mail

# usage
[[ "$(code "$binary" mail frobnicate)" == 2 ]] || fail 'bad usage exits 2'
# no engine: exit 4 (an empty PATH cannot reach a real podman or docker)
[[ "$(set +e; env BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_DATA_HOME="$tmp/data" HOME="$tmp/home" PATH="$tmp/nobin" "$binary" mail start --yes >/dev/null 2>&1; echo $?)" == 4 ]] || fail 'no container engine exits 4'
# ports are checked
[[ "$(code "$binary" mail start --smtp-port=80 --yes)" == 4 ]] || fail 'a privileged port exits 4'
[[ "$(code "$binary" mail start --smtp-port=2525 --ui-port=2525 --yes)" == 4 ]] || fail 'equal ports exit 4'
[[ "$(code "$binary" mail start --smtp-port=abc --yes)" == 4 ]] || fail 'a non-number port exits 4'

# start: plan first, dry run, then run (thrown away on stop: --rm and no volume)
[[ "$(code "$binary" mail start)" == 2 ]] || fail 'start plan exits 2'
[[ ! -d "$FAKE/containers/$c" ]] || fail 'the plan started nothing'
run "$binary" mail start --dry-run --json | jq -e '.dry_run and (.data.would | test("thrown away"))' >/dev/null || fail 'dry run'
run "$binary" mail start --yes --json | jq -e '.ok and .data.smtp == "127.0.0.1:1025" and .data.web == "http://127.0.0.1:8025" and .data.keep == false' >/dev/null || fail 'start'
runline="$(cat "$FAKE/containers/$c/run")"
[[ "$runline" == *"axllent/mailpit"* && "$runline" == *"--rm"* && "$runline" == *"-p 127.0.0.1:1025:1025"* && "$runline" == *"-p 127.0.0.1:8025:8025"* && "$runline" == *"MP_SMTP_AUTH_ACCEPT_ANY=1"* ]] || fail "run line: $runline"
[[ "$runline" != *"-v "* && "$runline" != *"MP_DATABASE"* ]] || fail 'no volume without --keep'
run "$binary" mail start --yes --json | jq -e '.data.already == "running"' >/dev/null || fail 'start twice is a no-op'
jq -e '.smtp == 1025 and .ui == 8025 and .keep == false' "$tmp/data/mail/meta.json" >/dev/null || fail 'meta file'

# stop throws the mail away (the fake removes --rm containers)
run "$binary" mail stop --json | jq -e '.data.stopped and (.data.kept == false)' >/dev/null || fail 'stop'
[[ ! -d "$FAKE/containers/$c" ]] || fail 'a stopped catcher without --keep is gone'
[[ "$(code "$binary" mail stop)" == 4 ]] || fail 'stop with nothing exits 4'

# --keep: a bind mount of the data folder and the database file, no --rm, restart policy
run "$binary" mail start --keep --smtp-port=2525 --ui-port=9025 --yes >/dev/null
runline="$(cat "$FAKE/containers/$c/run")"
[[ "$runline" == *"-v $tmp/data/mail:/data"* && "$runline" == *"MP_DATABASE=/data/mailpit.db"* && "$runline" == *"--restart unless-stopped"* && "$runline" != *"--rm"* && "$runline" == *"-p 127.0.0.1:2525:1025"* && "$runline" == *"-p 127.0.0.1:9025:8025"* ]] || fail "keep run line: $runline"
run "$binary" mail env --json | jq -e '.data.port == 2525 and .data.web == "http://127.0.0.1:9025"' >/dev/null || fail 'env follows the chosen ports'
run "$binary" mail stop >/dev/null; [[ "$(cat "$FAKE/containers/$c/state")" == exited ]] || fail 'a kept catcher stays, stopped'
run "$binary" mail start --yes >/dev/null; [[ "$(cat "$FAKE/containers/$c/state")" == running ]] || fail 'a stopped kept container is started again'
# remove: plan, keep-data, delete
[[ "$(code "$binary" mail remove)" == 2 ]] || fail 'remove plan exits 2'
run "$binary" mail remove --keep-data --yes >/dev/null; [[ ! -d "$FAKE/containers/$c" && -d "$tmp/data/mail" ]] || fail '--keep-data keeps the stored mail'
run "$binary" mail start --keep --yes >/dev/null; run "$binary" mail remove --yes >/dev/null; [[ ! -d "$FAKE/containers/$c" && ! -d "$tmp/data/mail" ]] || fail 'remove deletes the stored mail'
[[ "$(code "$binary" mail remove --yes)" == 4 ]] || fail 'remove with nothing exits 4'
rc=0; FAKE_FAIL=1 run "$binary" mail start --yes --json >/dev/null 2>&1 || rc=$?
[[ "$rc" == 6 ]] || fail "a failing container run exits 6, got $rc"

# the API: before the fake answers, everything that needs it exits 4
export BXRIG_MAIL_API="http://127.0.0.1:1"
[[ "$(code "$binary" mail list)" == 4 ]] || fail 'list without a catcher exits 4'
run "$binary" mail status --json | jq -e '.data.answering == false' >/dev/null || fail 'status says it is not answering'
python3 "$tmp/api.py" "$tmp/sent.json" > "$tmp/port" & srv=$!
for _ in $(seq 1 50); do [[ -s "$tmp/port" ]] && break; sleep 0.1; done
export BXRIG_MAIL_API="http://127.0.0.1:$(cat "$tmp/port")"
run "$binary" mail list --json | jq -e '(.data.total == 2) and (.data.unread == 1) and (.data.messages[0].mid == "AAAA1111") and (.data.messages[0].sender == "Shop") and (.data.messages[1].sender == "billing@example.test") and (.data.messages[1].attachment_count == 1) and (.data.messages[0].received == "2026-11-14 09:42:10") and (.data.messages[1].seen == true)' >/dev/null || fail 'list json'
run "$binary" mail list | grep -q 'Order shipped' || fail 'list text'
run "$binary" mail status --json | jq -e '.data.answering and .data.total == 2 and .data.unread == 1' >/dev/null || fail 'status counts'
run "$binary" mail show AAAA1111 | grep -q 'Your order is on its way' || fail 'show text body'
run "$binary" mail show BBBB2222 --json | jq -e '(.data.files[0].file_name == "invoice.pdf") and (.data.body_html | length > 0) and .data.body_text == ""' >/dev/null || fail 'show json with an attachment'
run "$binary" mail show BBBB2222 | grep -q 'HTML only' || fail 'an HTML-only message says so'
[[ "$(code "$binary" mail show ZZZZ9999)" == 4 ]] || fail 'unknown message exits 4'
[[ "$(code "$binary" mail show 'a;b')" == 2 ]] || fail 'a bad id exits 2'
# test sends a message through the API
run "$binary" mail test --to=dev@example.test --subject="Hello there" --json | jq -e '.ok and .data.recipient == "dev@example.test"' >/dev/null || fail 'test'
jq -e '.To[0].Email == "dev@example.test" and .Subject == "Hello there" and .From.Email == "bxrig@localhost"' "$tmp/sent.json" >/dev/null || fail 'the send request body'
run "$binary" mail list --json | jq -e '.data.total == 3 and .data.messages[0].mid == "CCCC3333"' >/dev/null || fail 'the test message arrived'
# delete one: plan, then it is gone
[[ "$(code "$binary" mail delete CCCC3333)" == 2 ]] || fail 'delete plan exits 2'
run "$binary" mail delete CCCC3333 --yes >/dev/null; run "$binary" mail list --json | jq -e '.data.total == 2' >/dev/null || fail 'delete'
[[ "$(code "$binary" mail delete ZZZZ9999 --yes)" == 4 ]] || fail 'delete of an unknown message exits 4'
# clear: plan, then empty
[[ "$(code "$binary" mail clear)" == 2 ]] || fail 'clear plan exits 2'
run "$binary" mail clear --dry-run --json | jq -e '.dry_run and .data.would_delete == 2' >/dev/null || fail 'clear dry run'
run "$binary" mail clear --yes >/dev/null; run "$binary" mail list --json | jq -e '.data.total == 0' >/dev/null || fail 'clear'
run "$binary" mail list | grep -q 'inbox is empty' || fail 'empty inbox text'
# open: a fake xdg-open records the address
printf '#!/bin/sh\necho "$@" >> "%s/opened"\n' "$tmp" > "$tmp/bin/xdg-open"; chmod +x "$tmp/bin/xdg-open"
run "$binary" mail open AAAA1111 >/dev/null; grep -q "/view/AAAA1111.html" "$tmp/opened" || fail 'open a message'
run "$binary" mail open --json | jq -e '.data.url == env.BXRIG_MAIL_API' >/dev/null || fail 'open the inbox'
# env
run "$binary" mail env | grep -q 'MAIL_PORT=' || fail 'env lists Laravel'
run "$binary" mail env --json | jq -e '(.data.settings | map(.stack) | index("Laravel (.env)")) != null' >/dev/null || fail 'env json'
echo "mail tests passed"

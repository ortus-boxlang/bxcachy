#!/usr/bin/env bash
# `bxrig backup data ...` with a fake restic (logs its arguments and the variables it was given), a fake systemctl and a temp home. Usage: backup-data-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
H="$tmp/home"; mkdir -p "$tmp/bin" "$H/Projects/app" "$H/Documents" "$H/.ssh" "$tmp/disk"; export LOG="$tmp/log"; : > "$LOG"
echo code > "$H/Projects/app/main.bx"
cat > "$tmp/bin/restic" <<'F'
#!/usr/bin/env bash
echo "restic $*" >> "$LOG"
echo "ENV repo=$RESTIC_REPOSITORY pw=${RESTIC_PASSWORD:+set} aws=${AWS_ACCESS_KEY_ID:-} secret=${AWS_SECRET_ACCESS_KEY:+set} region=${AWS_DEFAULT_REGION:-} b2=${B2_ACCOUNT_ID:-} gproj=${GOOGLE_PROJECT_ID:-} gcred=${GOOGLE_APPLICATION_CREDENTIALS:-}" >> "$LOG"
case "$1" in
  snapshots) printf '[{"id":"aaaaaaaaaaaa1111","short_id":"aaaaaaaa","time":"2026-11-10T10:00:00Z","hostname":"box","paths":["/home/dev/Projects"],"tags":["bxrig"]},{"id":"bbbbbbbbbbbb2222","short_id":"bbbbbbbb","time":"2026-11-12T10:00:00Z","hostname":"box","paths":["/home/dev/Projects"],"tags":["bxrig"]}]\n' ;;
  ls) printf '{"struct_type":"snapshot","id":"aaaaaaaa"}\n{"name":"main.bx","type":"file","path":"/home/dev/Projects/app/main.bx","size":5,"struct_type":"node"}\n' ;;
  backup) echo "snapshot cccccccc saved" ;;
esac
exit 0
F
printf '#!/usr/bin/env bash\necho "systemctl $*" >> "$LOG"\nexit 0\n' > "$tmp/bin/systemctl"
printf '#!/usr/bin/env bash\nif [[ "$1" == -u ]]; then echo 1000; else /usr/bin/id "$@"; fi\n' > "$tmp/bin/id"
printf '#!/usr/bin/env bash\necho "notify $*" >> "$LOG"\n' > "$tmp/bin/notify-send"
chmod +x "$tmp/bin"/*
echo '{"type":"service_account"}' > "$tmp/gcs.json"
printf 'AWS_ACCESS_KEY_ID=AKIAEXAMPLE\nAWS_SECRET_ACCESS_KEY=s3cr3tvalue\n' > "$tmp/keys"
run() { env HOME="$H" USER=dev BXRIG_CONFIG_HOME="$H/.config" BXRIG_DATA_HOME="$tmp/data" BXRIG_USER_UNIT_DIR="$tmp/units" BXRIG_SELF=/usr/bin/bxrig PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
has() { grep -qF -- "$1" "$LOG"; }

run "$binary" backup data status --json | jq -e '.data.schedule == "off" and .data.retention.daily == 7 and (.data.include | index("Projects") != null)' >/dev/null || fail 'defaults'
[[ "$(code "$binary" backup data nonsense)" == 2 ]] || fail 'usage exits 2'
run "$binary" backup data targets --json | jq -e '.data.targets == []' >/dev/null || fail 'no targets yet'

# ---- targets: every kind builds the repository address restic documents ----
[[ "$(code "$binary" backup data target add do --type=s3 --bucket=mybucket)" == 2 ]] || fail 's3 without keys exits 2'
[[ "$(code "$binary" backup data target add Bad --type=local --path=/x)" == 2 && "$(code "$binary" backup data target add x --type=ftp)" == 2 && "$(code "$binary" backup data target add x --type=s3)" == 2 ]] || fail 'bad target exits 2'
run "$binary" backup data target add do --type=s3 --endpoint=https://nyc3.digitaloceanspaces.com --bucket=mybucket --path=bx --region=nyc3 --keys-file="$tmp/keys" --json | jq -e '.data.repository == "s3:https://nyc3.digitaloceanspaces.com/mybucket/bx"' >/dev/null || fail 's3 repository'
! grep -rq 's3cr3tvalue' "$H/.config" || fail 'a key leaked into the config'
run "$binary" backup data target add b --type=b2 --bucket=bk --path=p --keys-file=<(printf 'B2_ACCOUNT_ID=id1\nB2_ACCOUNT_KEY=k1\n') --json | jq -e '.data.repository == "b2:bk:p"' >/dev/null || fail 'b2'
run "$binary" backup data target add az --type=azure --container=c1 --path=x --keys-file=<(printf 'AZURE_ACCOUNT_NAME=n\nAZURE_ACCOUNT_KEY=k\n') --json | jq -e '.data.repository == "azure:c1:/x"' >/dev/null || fail 'azure'
run "$binary" backup data target add gcs --type=gs --bucket=g1 --project=proj --credentials="$tmp/gcs.json" --path=r --json | jq -e '.data.repository == "gs:g1:/r"' >/dev/null || fail 'gs'
[[ "$(code "$binary" backup data target add gcs2 --type=gs --bucket=g1 --project=proj --credentials="$tmp/nope.json")" == 4 ]] || fail 'a missing credentials file exits 4'
run "$binary" backup data target add rc --type=rclone --remote=myftp --path=bk --json | jq -e '.data.repository == "rclone:myftp:bk"' >/dev/null || fail 'rclone (FTP and others)'
run "$binary" backup data target add ssh --type=sftp --host=nas.local --user=me --path=/srv/bk --json | jq -e '.data.repository == "sftp:me@nas.local:/srv/bk"' >/dev/null || fail 'sftp'
run "$binary" backup data target add rs --type=rest --url=https://rest.example.com:8000/ --keys-file=<(printf 'RESTIC_REST_USERNAME=u\nRESTIC_REST_PASSWORD=p\n') --json | jq -e '.data.repository == "rest:https://rest.example.com:8000/"' >/dev/null || fail 'rest'
run "$binary" backup data target add usb --type=local --path="$tmp/disk/repo" --json | jq -e ".data.repository == \"$tmp/disk/repo\"" >/dev/null || fail 'local'
[[ "$(code "$binary" backup data target add evil --type=local --path='/x;rm -rf')" == 2 && "$(code "$binary" backup data target add evil --type=s3 --bucket='a b')" == 2 ]] || fail 'shell characters are refused'
run "$binary" backup data targets --json | jq -e '(.data.targets | length == 8) and (.data.targets[0].name == "az")' >/dev/null || fail 'targets list'
run "$binary" backup data target remove rc --yes >/dev/null; run "$binary" backup data targets --json | jq -e '.data.targets | map(.name) | index("rc") == null' >/dev/null || fail 'remove'

# ---- init: the repository password is made and kept in the keyring, never on a command line ----
[[ "$(code "$binary" backup data init do)" == 2 ]] || fail 'init without --yes is a plan'
: > "$LOG"; run "$binary" backup data init do --yes >/dev/null
has 'restic init' && has 'repo=s3:https://nyc3.digitaloceanspaces.com/mybucket/bx pw=set aws=AKIAEXAMPLE secret=set region=nyc3' || fail "init env: $(cat "$LOG")"
! grep -q 's3cr3tvalue\|AKIAEXAMPLE' <(grep '^restic ' "$LOG") || fail 'a key reached restic arguments'
run "$binary" backup data targets --json | jq -e '.data.targets | map(select(.name == "do" and .password)) | length == 1' >/dev/null || fail 'the password is stored'
[[ "$(code "$binary" backup data run --target=b --yes)" == 4 ]] || fail 'run on a target that was not initialized exits 4'

# ---- run ----
: > "$LOG"; [[ "$(code "$binary" backup data run --target=do)" == 2 ]] || fail 'run without --yes is a plan'
! has 'restic backup' || fail 'the plan ran restic'
run "$binary" backup data run --target=do --yes >/dev/null
has "restic backup --tag bxrig --exclude-caches --one-file-system --exclude node_modules" && has "$H/Projects" && has "$H/Documents" && has "$H/.ssh" || fail "run: $(cat "$LOG")"
! has "$H/code" || fail 'a folder that does not exist was added'

# ---- default and --all ----
run "$binary" backup data default usb --json | jq -e '.data.default == "usb"' >/dev/null || fail 'default'
[[ "$(code "$binary" backup data default nowhere)" == 4 ]] || fail 'an unknown default exits 4'
run "$binary" backup data default do >/dev/null
: > "$LOG"; run "$binary" backup data run --all --yes >/dev/null
[[ "$(grep -c '^restic backup' "$LOG")" == 1 ]] && has 'repo=s3:https://nyc3.digitaloceanspaces.com/mybucket/bx' || fail "run --all backs up only the places that are set up: $(grep '^restic' "$LOG")"

# ---- list, files, restore ----
run "$binary" backup data list --target=do --json | jq -e '(.data.snapshots | map(.id)) == ["bbbbbbbb","aaaaaaaa"]' >/dev/null || fail 'list newest first'
run "$binary" backup data files aaaaaaaa --target=do --json | jq -e '.data.files | map(.path) == ["/home/dev/Projects/app/main.bx"]' >/dev/null || fail 'files'
[[ "$(code "$binary" backup data files 'a;b' --target=do)" == 2 ]] || fail 'a bad snapshot id exits 2'
[[ "$(code "$binary" backup data restore aaaaaaaa --target=do)" == 2 ]] || fail 'restore needs --to'
[[ "$(code "$binary" backup data restore aaaaaaaa --to="$tmp/out" --target=do)" == 2 ]] || fail 'restore without --yes is a plan'
[[ ! -e "$tmp/out" ]] || fail 'the plan created the folder'
: > "$LOG"; run "$binary" backup data restore aaaaaaaa --to="$tmp/out" --include=/home/dev/Projects/app --target=do --yes >/dev/null
has "restic restore aaaaaaaa --target $tmp/out --include /home/dev/Projects/app" || fail "restore: $(cat "$LOG")"
[[ "$(code "$binary" backup data restore aaaaaaaa --to=/tmp/../etc --target=do --yes)" == 2 ]] || fail 'restore refuses ..'

# ---- verify and forget ----
: > "$LOG"; run "$binary" backup data verify --target=do >/dev/null; has 'restic check' || fail 'verify'
run "$binary" backup data verify --target=do --deep >/dev/null; has 'restic check --read-data-subset 5%' || fail 'verify --deep'
[[ "$(code "$binary" backup data forget --target=do)" == 2 ]] || fail 'forget without --yes is a plan'
: > "$LOG"; run "$binary" backup data forget --target=do --yes >/dev/null; has 'restic forget --tag bxrig --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune' || fail 'retention flags'

run "$binary" backup data retention --daily=14 --monthly=12 --json | jq -e '.data.retention == {"daily":14,"weekly":4,"monthly":12}' >/dev/null || fail 'retention'
[[ "$(code "$binary" backup data retention --daily=lots)" == 2 ]] || fail 'bad retention exits 2'
: > "$LOG"; run "$binary" backup data forget --target=do --yes >/dev/null; has '--keep-daily 14 --keep-weekly 4 --keep-monthly 12' || fail 'retention is used by forget'

# ---- schedule ----
[[ "$(code "$binary" backup data schedule daily)" == 2 ]] || fail 'schedule without --yes is a plan'
[[ ! -e "$tmp/units/bxrig-backup.timer" ]] || fail 'the plan wrote a timer'
: > "$LOG"; run "$binary" backup data schedule daily --yes >/dev/null
grep -q '^OnCalendar=daily$' "$tmp/units/bxrig-backup.timer" && grep -q '^Persistent=true$' "$tmp/units/bxrig-backup.timer" || fail 'timer'
grep -q '^ExecStart=/usr/bin/bxrig backup data run --all --yes --scheduled$' "$tmp/units/bxrig-backup.service" && grep -q '^ConditionACPower=true$' "$tmp/units/bxrig-backup.service" || fail 'service skips on battery'
has 'systemctl --user enable --now bxrig-backup.timer' || fail 'timer enabled'
run "$binary" backup data status --json | jq -e '.data.schedule == "daily"' >/dev/null || fail 'status shows the schedule'
run "$binary" backup data schedule off --yes >/dev/null; [[ ! -e "$tmp/units/bxrig-backup.timer" ]] && has 'disable --now bxrig-backup.timer' || fail 'schedule off'

# ---- a failed scheduled backup tells you ----
printf '#!/usr/bin/env bash\necho "boom" >&2\nexit 1\n' > "$tmp/bin/restic"
: > "$LOG"; set +e; run "$binary" backup data run --target=do --yes --scheduled >/dev/null 2>&1; c=$?; set -e
[[ $c == 6 ]] && has 'notify Backup to do failed' || fail "a scheduled failure notifies (exit $c): $(cat "$LOG")"

# ---- include and exclude ----
run "$binary" backup data include add Music >/dev/null; run "$binary" backup data include --json | jq -e '.data.include | index("Music") != null' >/dev/null || fail 'include add'
run "$binary" backup data exclude add '*.iso' >/dev/null; run "$binary" backup data exclude remove node_modules >/dev/null; run "$binary" backup data exclude --json | jq -e '(.data.exclude | index("*.iso") != null) and (.data.exclude | index("node_modules") == null)' >/dev/null || fail 'exclude edit'
[[ "$(code "$binary" backup data include add 'a;b')" == 2 && "$(code "$binary" backup data include add '../x')" == 2 ]] || fail 'bad include exits 2'

# ---- a NAS target made by `nas use` ----
mkdir -p "$H/.config/bxrig"; jq '.targets["nas-syn"] = {"type":"nas","nas":"syn","share":"backups","path":"restic"}' "$H/.config/bxrig/backup.json" > "$tmp/b.json" && cp "$tmp/b.json" "$H/.config/bxrig/backup.json"
run "$binary" backup data targets --json | jq -e '.data.targets | map(select(.name == "nas-syn" and (.repository | test("/NAS/syn/backups/restic$")))) | length == 1' >/dev/null || fail 'the NAS target is listed'
[[ "$(code "$binary" backup data init nas-syn --yes)" == 4 ]] || fail 'an unmounted NAS share exits 4'
echo "backup-data-test: ok"

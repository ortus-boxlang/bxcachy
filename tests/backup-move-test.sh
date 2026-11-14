#!/usr/bin/env bash
# `bxrig backup send` and `backup export` with a fake restic. Usage: backup-move-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
H="$tmp/home"; mkdir -p "$tmp/bin" "$H/Projects" "$H/.config/hypr" "$tmp/disk"; export LOG="$tmp/log"; : > "$LOG"
echo hl > "$H/.config/hypr/hyprland.lua"
cat > "$tmp/bin/restic" <<'F'
#!/usr/bin/env bash
echo "restic $*" >> "$LOG"
echo "ENV repo=$RESTIC_REPOSITORY from=${RESTIC_FROM_REPOSITORY:-} fromcmd=${RESTIC_FROM_PASSWORD_COMMAND:-} frompw=${BXRIG_FROM_PW:+set} pw=${RESTIC_PASSWORD:+set} aws=${AWS_ACCESS_KEY_ID:-}" >> "$LOG"
exit 0
F
printf '#!/usr/bin/env bash\ncase "$1" in -Qqe|-Qqm) echo git ;; esac\n' > "$tmp/bin/pacman"
printf '#!/usr/bin/env bash\nif [[ "$1" == -u ]]; then echo 1000; else /usr/bin/id "$@"; fi\n' > "$tmp/bin/id"
chmod +x "$tmp/bin"/*
run() { env HOME="$H" USER=dev BXRIG_CONFIG_HOME="$H/.config" BXRIG_DATA_HOME="$tmp/data" BXRIG_SELF=/usr/bin/bxrig PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
has() { grep -qF -- "$1" "$LOG"; }
add_s3() { printf 'AWS_ACCESS_KEY_ID=%s\nAWS_SECRET_ACCESS_KEY=sec\n' "$2" > "$tmp/k-$1"; run "$binary" backup data target add "$1" --type=s3 --bucket="$1-bucket" --keys-file="$tmp/k-$1" >/dev/null; }

run "$binary" backup data target add usb --type=local --path="$tmp/disk/repo" >/dev/null; add_s3 cloud AKIAONE; add_s3 other AKIATWO
for t in usb cloud other; do run "$binary" backup data init "$t" --yes >/dev/null; done

# ---- send ----
[[ "$(code "$binary" backup send)" == 2 && "$(code "$binary" backup send 'a;b' --to=cloud)" == 2 && "$(code "$binary" backup send aaaaaaaa)" == 2 ]] || fail 'bad usage exits 2'
[[ "$(code "$binary" backup send aaaaaaaa --from=usb --to=usb)" == 2 ]] || fail 'the same target is refused'
[[ "$(code "$binary" backup send aaaaaaaa --from=usb --to=nowhere)" == 4 ]] || fail 'an unknown destination exits 4'
: > "$LOG"; [[ "$(code "$binary" backup send aaaaaaaa --from=usb --to=cloud)" == 2 ]] || fail 'send without --yes is a plan'
! has 'restic copy' || fail 'the plan ran restic'
run "$binary" backup send aaaaaaaa --from=usb --to=cloud --yes >/dev/null
has 'restic copy aaaaaaaa' || fail "copy: $(cat "$LOG")"
has "repo=s3:s3.amazonaws.com/cloud-bucket from=$tmp/disk/repo fromcmd=printenv BXRIG_FROM_PW frompw=set pw=set aws=AKIAONE" || fail "the environment of the copy: $(cat "$LOG")"
! grep -q 'pw=.*[0-9a-f]\{32\}' "$LOG" || fail 'a password reached the log'
: > "$LOG"; run "$binary" backup send all --from=usb --to=cloud --yes >/dev/null; has 'restic copy' && ! has 'restic copy all' || fail 'send all copies without an id'
[[ "$(code "$binary" backup send aaaaaaaa --from=cloud --to=other --yes)" == 4 ]] || fail 'two S3 accounts cannot share one command'

# ---- export data ----
: > "$LOG"; [[ "$(code "$binary" backup export data latest --to="$tmp/out.tar" --target=usb)" == 2 ]] || fail 'export without --yes is a plan'
run "$binary" backup export data latest --to="$tmp/out.tar" --target=usb --yes >/dev/null
has "restic dump --archive tar --target $tmp/out.tar latest /" || fail "dump: $(cat "$LOG")"
run "$binary" backup export data latest --to="$tmp/out.zip" --path=/home/dev/Projects --target=usb --yes >/dev/null
has "restic dump --archive zip --target $tmp/out.zip latest /home/dev/Projects" || fail 'a .zip name makes a zip, --path limits it'
touch "$tmp/exists.tar"; [[ "$(code "$binary" backup export data latest --to="$tmp/exists.tar" --target=usb --yes)" == 4 ]] || fail 'an existing file is never overwritten'
[[ "$(code "$binary" backup export data latest --to="$tmp/x.tar" --path=relative --target=usb --yes)" == 2 && "$(code "$binary" backup export data latest --to=/tmp/../x.tar --target=usb --yes)" == 2 ]] || fail 'bad path exits 2'

# ---- export config ----
id="$(run "$binary" backup config now --json | jq -r '.data.snapshot.id')"
run "$binary" backup export config "$id" --to="$tmp/mine.tar.gz" --yes >/dev/null; tar -tzf "$tmp/mine.tar.gz" | grep -q 'files/.config/hypr/hyprland.lua' || fail 'a config snapshot exports as a tar.gz'
[[ "$(code "$binary" backup export config 20000101T000000 --to="$tmp/n.tar.gz" --yes)" == 4 ]] || fail 'unknown snapshot exits 4'

# ---- config snapshots ride along in the data backups ----
run "$binary" backup data status --json | jq -e '.data.include | index(".local/share/bxrig/backups/config") != null' >/dev/null || fail 'config snapshots are in the data backup by default'
echo "backup-move-test: ok"

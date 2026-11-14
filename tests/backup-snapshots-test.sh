#!/usr/bin/env bash
# `bxrig backup snapshots ...` with fake snapper, timeshift, findmnt, systemctl, pacman and sudo. Usage: backup-snapshots-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home"; export LOG="$tmp/log"; : > "$LOG"
cat > "$tmp/snapper.real" <<'F'
#!/usr/bin/env bash
echo "snapper $*" >> "$LOG"
case "$*" in
  *list-configs*) [[ -e "$FAKEDIR/configured" ]] && echo root ;;
  *"-c root list"*) printf '{"root":[{"number":0,"type":"single","date":"","description":"current"},{"number":1,"type":"single","date":"2026-11-10 10:00:00","description":"first"},{"number":2,"type":"pre","date":"2026-11-12 09:00:00","description":"pacman -Syu"}]}\n' ;;
  *status*) printf '+..... /etc/new\nc..... /etc/hosts\n' ;;
esac
F
printf '#!/usr/bin/env bash\necho "timeshift $*" >> "$LOG"\necho "Num Name Tags Description"\n' > "$tmp/timeshift.real"
printf '#!/usr/bin/env bash\necho "findmnt $*" >> "$LOG"\n' > "$tmp/bin/findmnt"
printf '#!/usr/bin/env bash\necho "systemctl $*" >> "$LOG"\n[[ "$1" == is-active ]] && exit "${ACTIVE:-3}"\nexit 0\n' > "$tmp/bin/systemctl"
printf '#!/usr/bin/env bash\necho "pacman $*" >> "$LOG"\n' > "$tmp/bin/pacman"
printf '#!/usr/bin/env bash\n[[ "$1" == --version ]] && { echo "Sudo version 1.9"; exit 0; }\nexec "$@"\n' > "$tmp/bin/sudo"
chmod +x "$tmp/bin"/* "$tmp/snapper.real" "$tmp/timeshift.real"
mkdir -p "$tmp/fake"; export FAKEDIR="$tmp/fake"
run() { env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" FAKEDIR="$tmp/fake" PATH="$tmp/bin:$PATH" LOG="$LOG" BXRIG_ROOT_FS="${FS:-btrfs}" BXRIG_BOOTLOADER="${BL:-limine}" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
has() { grep -qF -- "$1" "$LOG"; }

[[ "$(code "$binary" backup snapshots nonsense)" == 2 ]] || fail 'usage exits 2'
run "$binary" backup snapshots status --json | jq -e '.data.filesystem == "btrfs" and .data.tool == ""' >/dev/null || fail 'status without a tool'
[[ "$(code "$binary" backup snapshots list)" == 4 ]] || fail 'list without a tool exits 4'

# ---- setup on Btrfs ----
[[ "$(code "$binary" backup snapshots setup)" == 2 ]] || fail 'setup without --yes is a plan'
run "$binary" backup snapshots setup --dry-run --json | jq -e '.data.commands | (map(select(test("pacman -S --needed --noconfirm snapper snap-pac"))) | length == 1) and (map(select(test("snapper -c root create-config /"))) | length == 1) and (map(select(test("TIMELINE_LIMIT_HOURLY=5 TIMELINE_LIMIT_DAILY=7"))) | length == 1) and (map(select(test("enable --now snapper-timeline.timer snapper-cleanup.timer"))) | length == 1) and (map(select(test("grub-btrfs"))) | length == 0)' >/dev/null || fail "setup plan: $(run "$binary" backup snapshots setup --dry-run)"
run "$binary" backup snapshots setup --dry-run | grep -q 'grub-btrfs (boot entries for snapshots) is skipped' || fail 'grub-btrfs is skipped without GRUB'
BL=grub run "$binary" backup snapshots setup --home --dry-run --json | jq -e '.data.commands | (map(select(test("snapper snap-pac grub-btrfs"))) | length == 1) and (map(select(test("-c home create-config /home"))) | length == 1) and (map(select(test("enable --now grub-btrfsd.service"))) | length == 1)' >/dev/null || fail 'GRUB and --home'

# ---- setup elsewhere: Timeshift ----
FS=ext4 run "$binary" backup snapshots setup --dry-run | grep -q 'pacman -S --needed --noconfirm timeshift' || fail 'ext4 installs Timeshift'
FS=ext4 run "$binary" backup snapshots setup --dry-run | grep -q 'full copies' || fail 'ext4 says what Timeshift does'

# ---- snapper in use ----
cp "$tmp/snapper.real" "$tmp/bin/snapper"; touch "$tmp/fake/configured"
run "$binary" backup snapshots status --json | jq -e '.data.tool == "snapper" and (.data.configs == ["root"]) and .data.snapshots == 2' >/dev/null || fail "status: $(run "$binary" backup snapshots status --json)"
run "$binary" backup snapshots list --json | jq -e '(.data.snapshots | map(.number)) == [2,1] and .data.snapshots[0].description == "pacman -Syu"' >/dev/null || fail 'list drops snapshot 0 and sorts newest first'
[[ "$(code "$binary" backup snapshots create)" == 2 ]] || fail 'create without --yes is a plan'
: > "$LOG"; run "$binary" backup snapshots create --description='before the move' --yes >/dev/null; has 'snapper -c root create --description before the move -p' || fail "create: $(cat "$LOG")"
[[ "$(code "$binary" backup snapshots create --description='a;b' --yes)" == 2 ]] || fail 'a bad description exits 2'
: > "$LOG"; run "$binary" backup snapshots delete 1 --yes >/dev/null; has 'snapper -c root delete 1' || fail 'delete'
[[ "$(code "$binary" backup snapshots delete one --yes)" == 2 ]] || fail 'a bad id exits 2'
run "$binary" backup snapshots changes 1 | grep -q '/etc/hosts' || fail 'changes'
run "$binary" backup snapshots restore 1 /home/me/app --dry-run | grep -q 'snapper -c root undochange 1..0 /home/me/app' || fail 'restore plan'
[[ "$(code "$binary" backup snapshots restore 1 relative --yes)" == 2 && "$(code "$binary" backup snapshots restore 1 '/a/../etc' --yes)" == 2 ]] || fail 'restore paths are absolute and without ..'
: > "$LOG"; run "$binary" backup snapshots restore 1 /home/me/app --yes >/dev/null; has 'snapper -c root undochange 1..0 /home/me/app' || fail 'restore'

# ---- Timeshift in use ----
rm "$tmp/bin/snapper"; cp "$tmp/timeshift.real" "$tmp/bin/timeshift"
FS=ext4 run "$binary" backup snapshots status --json | jq -e '.data.tool == "timeshift"' >/dev/null || fail 'timeshift status'
: > "$LOG"; FS=ext4 run "$binary" backup snapshots create --description=x --yes >/dev/null; has 'timeshift --create --comments x --tags O' || fail 'timeshift create'
[[ "$(FS=ext4 code "$binary" backup snapshots delete 1 --yes)" == 4 ]] || fail 'snapper-only commands say so under Timeshift'
echo "backup-snapshots-test: ok"

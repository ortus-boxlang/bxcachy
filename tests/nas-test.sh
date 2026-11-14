#!/usr/bin/env bash
# `bxrig nas ...` with fake avahi-browse, smbclient, showmount, findmnt, sudo, rsync and a fake /etc. Usage: nas-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/etc/cred" "$tmp/etc/systemd" "$tmp/fake" "$tmp/src"; export LOG="$tmp/log"; : > "$LOG"
echo hello > "$tmp/src/a.txt"
cat > "$tmp/bin/avahi-browse" <<'F'
#!/usr/bin/env bash
case "$*" in
  *_smb._tcp*) printf '+;eth0;IPv4;DS920;_smb._tcp;local\n=;eth0;IPv4;DS920;_smb._tcp;local;ds920.local;192.168.1.20;445;"x"\n=;eth0;IPv6;DS920;_smb._tcp;local;ds920.local;fe80::1;445;"x"\n' ;;
  *_nfs._tcp*) printf '=;eth0;IPv4;DS920;_nfs._tcp;local;ds920.local;192.168.1.20;2049;"x"\n=;eth0;IPv4;Other;_nfs._tcp;local;other.local;192.168.1.30;2049;"x"\n' ;;
esac
F
cat > "$tmp/bin/smbclient" <<'F'
#!/usr/bin/env bash
echo "smbclient $*" >> "$LOG"
auth=""; while [[ $# -gt 0 ]]; do [[ "$1" == -A ]] && auth="$2"; shift; done
[[ -n "$auth" ]] && cat "$auth" >> "$LOG.auth"
grep -q 'password = wrongpass' "$auth" && { echo "session setup failed: NT_STATUS_LOGON_FAILURE" >&2; exit 1; }
printf 'Disk|backups|Backups\nDisk|photos|Photos\nDisk|IPC$|IPC\nIPC|IPC$|IPC Service\n'
F
printf '#!/usr/bin/env bash\necho "showmount $*" >> "$LOG"\nprintf "/volume1/backups 192.168.1.0/24\\n/volume1/media *\\n"\n' > "$tmp/bin/showmount"
printf '#!/usr/bin/env bash\n[[ -e "$FAKE/mounted" ]] && { echo cifs; exit 0; }\nexit 1\n' > "$tmp/bin/findmnt"
printf '#!/usr/bin/env bash\necho "rsync $*" >> "$LOG"\n' > "$tmp/bin/rsync"
printf '#!/usr/bin/env bash\necho "mount.cifs" > /dev/null\n' > "$tmp/bin/mount.cifs"; cp "$tmp/bin/mount.cifs" "$tmp/bin/mount.nfs"
printf '#!/usr/bin/env bash\nif [[ "$1" == -u ]]; then echo 1000; else echo 1000; fi\n' > "$tmp/bin/id"
# fake sudo: install and rm act on the fake /etc; everything else is only logged (mount, systemctl, pacman)
cat > "$tmp/bin/sudo" <<'F'
#!/usr/bin/env bash
[[ "$1" == --version ]] && { echo "Sudo version 1.9"; exit 0; }
echo "sudo $*" >> "$LOG"
case "$1" in
  install) shift; args=(); while [[ $# -gt 0 ]]; do case "$1" in -o|-g) shift 2 ;; *) args+=("$1"); shift ;; esac; done; exec install "${args[@]}" ;;
  rm) shift; exec rm "$@" ;;
  mount) touch "$FAKE/mounted" ;;
  umount) rm -f "$FAKE/mounted" ;;
esac
exit 0
F
chmod +x "$tmp/bin"/*
run() { env HOME="$tmp/home" USER=dev BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_DATA_HOME="$tmp/data" BXRIG_NAS_CRED_DIR="$tmp/etc/cred" BXRIG_SYSTEMD_DIR="$tmp/etc/systemd" BXRIG_NAS_HOME="$tmp/NAS" PATH="$tmp/bin:$PATH" LOG="$LOG" FAKE="$tmp/fake" BXRIG_NAS_REACH="${REACH:-yes}" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
has() { grep -qF -- "$1" "$LOG"; }
printf 'secret123\n' > "$tmp/pw"; printf 'wrongpass\n' > "$tmp/pw.bad"

[[ "$(code "$binary" nas nonsense)" == 2 ]] || fail 'usage exits 2'
run "$binary" nas list --json | jq -e '.data.nas == []' >/dev/null || fail 'empty list'

# ---- discover ----
run "$binary" nas discover --json | jq -e '(.data.nas | length == 2) and (.data.nas[0].address == "192.168.1.20") and (.data.nas[0].protocols == ["smb","nfs"])' >/dev/null || fail "discover: $(run "$binary" nas discover --json)"

# ---- setup is a plan ----
[[ "$(code "$binary" nas setup)" == 2 ]] || fail 'setup without --yes is a plan'
run "$binary" nas setup --dry-run | grep -q 'pacman -S --needed --noconfirm cifs-utils nfs-utils smbclient avahi nss-mdns rsync' || fail 'setup plan'

# ---- add ----
[[ "$(code "$binary" nas add Bad_Name --host=x)" == 2 && "$(code "$binary" nas add syn)" == 2 && "$(code "$binary" nas add syn --host=ds920.local)" == 2 ]] || fail 'bad add exits 2 (name, host, smb needs user)'
[[ "$(code "$binary" nas add syn --host=ds920.local --user=me)" == 2 ]] || fail 'smb without a password exits 2'
run "$binary" nas add syn --host=ds920.local --user=me --password-file="$tmp/pw" --json | jq -e '.data.password_key == "BXRIG_NAS_SYN_PASSWORD" and .data.protocol == "smb"' >/dev/null || fail 'add smb'
! grep -rq 'secret123' "$tmp/cfg" || fail 'the password leaked into the config'
run "$binary" nas add vault --host=192.168.1.30 --protocol=nfs >/dev/null || fail 'add nfs needs no user or password'
run "$binary" nas list --json | jq -e '(.data.nas | map(.name)) == ["syn","vault"]' >/dev/null || fail 'list'
run "$binary" nas show syn | grep -q 'smb://ds920.local' || fail 'show'
[[ "$(code "$binary" nas show nothing)" == 4 ]] || fail 'unknown NAS exits 4'

# ---- shares ----
run "$binary" nas shares syn --json | jq -e '(.data.shares | map(.name)) == ["backups","photos"]' >/dev/null || fail 'smb shares (no IPC$)'
grep -q 'password = secret123' "$LOG.auth" || fail 'smbclient was given the password through an auth file'
! grep -q 'secret123' "$LOG" || fail 'the password reached a command line'
run "$binary" nas shares vault --json | jq -e '(.data.shares | map(.name)) == ["/volume1/backups","/volume1/media"]' >/dev/null || fail 'nfs exports'

# ---- mount: a plan, then the commands ----
[[ "$(code "$binary" nas mount syn backups)" == 2 ]] || fail 'mount without --yes is a plan'
run "$binary" nas mount syn backups --dry-run | grep -q "credentials=$tmp/etc/cred/syn.cred,uid=1000,gid=1000,iocharset=utf8,file_mode=0600,dir_mode=0700" || fail 'mount options are private to you'
run "$binary" nas mount syn backups --dry-run | grep -q 'root only, mode 600' || fail 'the plan says why a root-only file exists'
: > "$LOG"; run "$binary" nas mount syn backups --yes >/dev/null
has "sudo mount -t cifs //ds920.local/backups $tmp/NAS/syn/backups" || fail "mount: $(cat "$LOG")"
[[ "$(stat -c %a "$tmp/etc/cred/syn.cred")" == 600 ]] && grep -q '^username=me$' "$tmp/etc/cred/syn.cred" && grep -q '^password=secret123$' "$tmp/etc/cred/syn.cred" || fail 'credentials file'
[[ -d "$tmp/NAS/syn/backups" ]] || fail 'the mount point was created'
run "$binary" nas mount vault /volume1/media --yes >/dev/null; has "sudo mount -t nfs 192.168.1.30:/volume1/media $tmp/NAS/vault/media" || fail 'nfs mount'
: > "$LOG"; run "$binary" nas unmount syn backups --yes >/dev/null; has "sudo umount $tmp/NAS/syn/backups" || fail 'unmount'
[[ "$(code "$binary" nas mount syn '../etc' --yes)" == 2 ]] || fail 'a bad share name exits 2'
echo vers > /dev/null; run "$binary" nas add syn --host=ds920.local --user=me --vers=3.1.1 --password-file="$tmp/pw" >/dev/null
run "$binary" nas mount syn backups --dry-run | grep -q 'vers=3.1.1' || fail '--vers is passed'
run "$binary" nas add syn --host=ds920.local --user=me --password-file="$tmp/pw" >/dev/null

# ---- auto: systemd mount and automount units ----
[[ "$(code "$binary" nas auto on syn backups)" == 2 ]] || fail 'auto on without --yes is a plan'
[[ ! -e "$tmp/etc/systemd/home-dev-NAS-syn-backups.mount" ]] || fail 'the plan wrote a unit'
mnt="$(systemd-escape -p --suffix=mount "$tmp/NAS/syn/backups")"; aut="$(systemd-escape -p --suffix=automount "$tmp/NAS/syn/backups")"
: > "$LOG"; run "$binary" nas auto on syn backups --yes >/dev/null
grep -q "^What=//ds920.local/backups$" "$tmp/etc/systemd/$mnt" && grep -q "^Type=cifs$" "$tmp/etc/systemd/$mnt" && grep -q ',nofail' "$tmp/etc/systemd/$mnt" || fail "mount unit: $(cat "$tmp/etc/systemd/$mnt" 2>/dev/null)"
grep -q "^Where=$tmp/NAS/syn/backups$" "$tmp/etc/systemd/$aut" && grep -q '^TimeoutIdleSec=600$' "$tmp/etc/systemd/$aut" && grep -q '^WantedBy=multi-user.target$' "$tmp/etc/systemd/$aut" || fail 'automount unit'
has "sudo systemctl enable --now $aut" && has 'sudo systemctl daemon-reload' || fail 'the automount is enabled'
run "$binary" nas show syn | grep -q 'automatic' || fail 'show marks the automatic share'
[[ "$(code "$binary" nas remove syn --yes)" == 4 ]] || fail 'a NAS with automatic mounts is not removed'
run "$binary" nas auto off syn backups --yes >/dev/null; [[ ! -e "$tmp/etc/systemd/$mnt" && ! -e "$tmp/etc/systemd/$aut" ]] || fail 'auto off removes the units'
has "sudo systemctl disable --now $aut" || fail 'auto off disables it'

# ---- test ----
touch "$tmp/fake/mounted"; mkdir -p "$tmp/NAS/syn/backups"
run "$binary" nas test syn backups --json | jq -e '.ok and (.data.checks | map(.id) | index("writable") != null) and (.data.checks | map(select(.id=="mounted" and .ok)) | length == 1)' >/dev/null || fail "test: $(run "$binary" nas test syn backups)"
rm -f "$tmp/fake/mounted"; [[ "$(code "$binary" nas test syn backups)" == 4 ]] || fail 'a share that is not mounted fails the test'
{ REACH=no run "$binary" nas test syn --json || true; } | jq -e '.data.checks | map(select(.id=="reachable" and (.ok | not))) | length == 1' >/dev/null || fail 'an unreachable NAS is reported'
run "$binary" nas add bad --host=ds920.local --user=me --password-file="$tmp/pw.bad" >/dev/null
{ run "$binary" nas test bad --json || true; } | jq -e '.data.checks | map(select(.id=="signed-in" and (.ok | not))) | length == 1' >/dev/null || fail 'a wrong password is reported as sign-in failed'

# ---- sync: a plain mirror, no delete unless asked ----
touch "$tmp/fake/mounted"; : > "$LOG"
[[ "$(code "$binary" nas sync syn "$tmp/src")" == 2 ]] || fail 'sync needs --to'
[[ "$(code "$binary" nas sync syn "$tmp/src" --to=backups/files)" == 2 ]] || fail 'sync without --yes is a plan'
run "$binary" nas sync syn "$tmp/src" --to=backups/files --yes >/dev/null; has "rsync -a --info=stats1 $tmp/src/ $tmp/NAS/syn/backups/files/" || fail "rsync: $(cat "$LOG")"
! has '--delete' || fail 'rsync deleted without --delete'
run "$binary" nas sync syn "$tmp/src" --to=backups/files --delete --dry-run | grep -q 'REMOVED from the NAS' || fail '--delete is called out in the plan'

# ---- use as a backup target ----
run "$binary" nas use syn backups --path=restic --json | jq -e ".data.repository == \"$tmp/NAS/syn/backups/restic\"" >/dev/null || fail 'use'
jq -e '.targets["nas-syn"] == {"type":"nas","nas":"syn","share":"backups","path":"restic"}' "$tmp/cfg/bxrig/backup.json" >/dev/null || fail 'backup.json target'
[[ "$(code "$binary" nas use syn backups --path='../x')" == 2 ]] || fail 'a bad path exits 2'

# ---- remove ----
run "$binary" nas remove vault --yes >/dev/null; run "$binary" nas list --json | jq -e '(.data.nas | map(.name) | index("vault")) == null' >/dev/null || fail 'remove'
echo "nas-test: ok"

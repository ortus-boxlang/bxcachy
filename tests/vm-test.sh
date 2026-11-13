#!/usr/bin/env bash
# `bxcachy vm ...` with a stateful fake podman and docker, and fake xdg-open and FreeRDP. Usage: vm-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/fake"; export LOG="$tmp/log"; : > "$LOG"
cat > "$tmp/bin/podman" <<'FAKE'
#!/usr/bin/env bash
echo "$(basename "$0") $*" >> "$LOG"
S="$FAKE/containers"; mkdir -p "$S"
case "$1" in
  --version) echo "$(basename "$0") version 5" ;;
  run) name=""; envf=""
       for ((i=1;i<=$#;i++)); do [[ "${!i}" == --name ]] && { j=$((i+1)); name="${!j}"; }; [[ "${!i}" == --env-file ]] && { j=$((i+1)); envf="${!j}"; }; done
       echo "$*" > "$S/$name.args"; [[ -n "$envf" ]] && cp "$envf" "$S/$name.env"; echo running > "$S/$name.state"; echo abc123 ;;
  container) name="${@: -1}"; [[ -f "$S/$name.state" ]] && cat "$S/$name.state" || exit 1 ;;
  start) echo running > "$S/$2.state" ;;
  stop) echo exited > "$S/$2.state" ;;
  rm) shift; for a in "$@"; do if [[ $a != -f ]]; then rm -f "${S:?}/${a:?}.state" "${S:?}/${a:?}.args"; fi; done ;;
  logs) echo "log line" ;;
esac
FAKE
cp "$tmp/bin/podman" "$tmp/bin/docker"
for t in xdg-open sdl-freerdp3; do printf '#!/usr/bin/env bash\necho "%s $*" >> "$LOG"\n' "$t" > "$tmp/bin/$t"; done
chmod +x "$tmp/bin"/*
mkdir -p "$tmp/dri"; echo 'MemTotal:       16000000 kB' > "$tmp/meminfo"; : > "$tmp/kvm"
run() { env HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_DATA_HOME="$tmp/data" PATH="$tmp/bin:$PATH" LOG="$LOG" FAKE="$tmp/fake" BXCACHY_VM_NO_WAIT=1 BXCACHY_VM_SKIP_KVM_CHECK=1 BXCACHY_MEMINFO_FILE="$tmp/meminfo" BXCACHY_DRI_DIR="$tmp/dri" BXCACHY_KVM_DEVICE="$tmp/kvm" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
args() { cat "$tmp/fake/containers/$1.args"; }

# the tables
run "$binary" vm versions linux --json | jq -e '.data.default == "ubuntu-xfce" and (.data.tags | length == 21) and (.data.tags | map(.id) | index("arch-kde") != null) and (.data.tags | map(select(.id == "alpine-xfce")) | .[0].tag == "latest")' >/dev/null || fail 'linux tags'
run "$binary" vm versions windows --json | jq -e '.data.default == "11" and (.data.versions | length == 25) and (.data.versions | map(select(.curated)) | length == 10)' >/dev/null || fail 'windows versions'
run "$binary" vm versions windows | grep -q 'UNOFFICIAL' || fail 'tiny11 is labelled unofficial'
[[ "$(code "$binary" vm versions beos)" == 2 ]] || fail 'versions usage'

# doctor
{ run "$binary" vm doctor --json || true; } | jq -e '(.data.checks | map(select(.check | test("KVM")) | .ok) == [true]) and (.data.checks | length >= 7)' >/dev/null || fail 'doctor'
{ run env BXCACHY_KVM_DEVICE="$tmp/nokvm" "$binary" vm doctor --json || true; } | jq -e '(.data.checks | map(select(.check | test("KVM")) | .ok) == [false])' >/dev/null || fail 'doctor without kvm'

# usage and validation
[[ "$(code "$binary" vm create linux)" == 2 ]] || fail 'a Linux desktop needs a name'
[[ "$(code "$binary" vm create linux Bad_Name --yes)" == 4 ]] || fail 'bad name'
[[ "$(code "$binary" vm create linux dev --tag=nope --yes)" == 4 ]] || fail 'unknown tag'
[[ "$(code "$binary" vm create linux dev --version=11)" == 2 ]] || fail '--version is for Windows'
[[ "$(code "$binary" vm create windows w1 --gpu=nvidia)" == 2 ]] || fail '--gpu is for Linux'

# Linux: plan, dry run, create
[[ "$(code "$binary" vm create linux dev)" == 2 ]] || fail 'plan without --yes exits 2'
run "$binary" vm create linux dev --dry-run --json | jq -e '.dry_run and .data.ports.web == 3001 and .data.tag == "ubuntu-xfce" and (.data.data | endswith("/vms/dev"))' >/dev/null || fail 'dry run plan'
[[ ! -e "$tmp/fake/containers/bxcachy-vm-dev.args" && ! -e "$tmp/cfg/bxcachy/vms/dev.json" ]] || fail 'dry run created something'
run "$binary" vm create linux dev --yes --json | jq -e '.ok and .data.container == "bxcachy-vm-dev" and .data.password_key == "BXCACHY_VM_DEV_PASSWORD"' >/dev/null || fail 'create linux'
a="$(args bxcachy-vm-dev)"
for want in "-p 127.0.0.1:3001:3001" "lscr.io/linuxserver/webtop:ubuntu-xfce" "--shm-size 1gb" "PUID=0" "PGID=0" "--restart unless-stopped" "-v $tmp/data/vms/dev/config:/config" "-v $tmp/home/Shared:/config/Shared" "io.bxcachy.vm.kind=linux"; do [[ "$a" == *"$want"* ]] || fail "linux run args miss '$want': $a"; done
[[ "$a" != *"--device"* && "$a" != *"--gpus"* ]] || fail 'no GPU unless asked'
grep -q '^CUSTOM_USER=bxcachy$' "$tmp/fake/containers/bxcachy-vm-dev.env" && grep -Eq '^PASSWORD=[0-9a-f]{32}$' "$tmp/fake/containers/bxcachy-vm-dev.env" || fail "env file: $(cat "$tmp/fake/containers/bxcachy-vm-dev.env")"
[[ ! -e "$tmp/data/vms/dev/vm.env" ]] || fail 'the env file must not be left behind'
[[ "$(stat -c %a "$tmp/cfg/bxcachy/vms/dev.json")" == 600 && -d "$tmp/home/Shared" ]] || fail 'record mode and the shared folder'
pw="$(grep '^PASSWORD=' "$tmp/fake/containers/bxcachy-vm-dev.env" | cut -d= -f2)"
run "$binary" vm info dev --show-password --json | jq -e --arg pw "$pw" '.data.password == $pw and .data.user == "bxcachy"' >/dev/null || fail 'the stored password is the one the container got'
info_text="$(run "$binary" vm info dev)"
[[ "$info_text" == *"show-password"* && "$info_text" != *"$pw"* ]] || fail 'info hides the password'
[[ "$(code "$binary" vm create linux dev --yes)" == 4 ]] || fail 'a second VM with the same name'

# more desktops: their own ports, a tag, GPU, resources, no shared folder
[[ "$(code "$binary" vm create linux gpu1 --tag=alpine-xfce --gpu=nvidia --yes)" == 4 ]] || fail 'Alpine has no NVIDIA support'
[[ "$(code "$binary" vm create linux gpu1 --tag=arch-kde --gpu=cuda --yes)" == 4 ]] || fail 'unknown gpu mode'
run "$binary" vm create linux arch1 --tag=arch-kde --gpu=intel --cpus=2 --memory=4G --share=none --yes >/dev/null || fail 'create arch1'
a="$(args bxcachy-vm-arch1)"
[[ "$a" == *"-p 127.0.0.1:3002:3001"* && "$a" == *"webtop:arch-kde"* && "$a" == *"--device /dev/dri"* ]] || fail "arch1 args: $a"
[[ "$a" == *"--cpus 2"* && "$a" == *"--memory 4G"* && "$a" != *"/config/Shared"* ]] || fail "arch1 resources and no share: $a"
run "$binary" vm create linux nv --tag=debian-xfce --gpu=nvidia --yes >/dev/null || fail 'create nvidia on podman'
a="$(args bxcachy-vm-nv)"; [[ "$a" == *"--device nvidia.com/gpu=all"* && "$a" == *"--device /dev/nvidia-modeset"* && "$a" != *"--gpus"* ]] || fail "podman nvidia (CDI): $a"
mkdir -p "$tmp/cfg/bxcachy"; echo '{"engine":"docker"}' > "$tmp/cfg/bxcachy/db.json"
run "$binary" vm create linux nvd --tag=ubuntu-xfce --gpu=nvidia --yes >/dev/null || fail 'create nvidia on docker'
a="$(args bxcachy-vm-nvd)"; [[ "$a" == *"--runtime nvidia --gpus all --device /dev/nvidia-modeset"* && "$a" == *"PUID=$(id -u)"* && "$a" == *"PGID=$(id -g)"* ]] || fail "docker nvidia: $a"
grep -q '^docker run' "$LOG" || fail 'docker was used when chosen'
rm -f "$tmp/cfg/bxcachy/db.json"
[[ "$(code env BXCACHY_DRI_DIR="$tmp/none" "$binary" vm create linux g2 --gpu=amd --yes)" == 4 ]] || fail 'intel and amd need /dev/dri'

# Windows
if command -v setsid >/dev/null; then [[ "$(set +e; setsid -w env HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_DATA_HOME="$tmp/data" PATH="$tmp/bin:$PATH" LOG="$LOG" FAKE="$tmp/fake" "$binary" vm create windows --yes </dev/null >/dev/null 2>&1; echo $?)" == 4 ]] || fail 'no terminal and no --version exits 4'; fi
[[ "$(code "$binary" vm create windows w0 --version=beos --yes)" == 4 ]] || fail 'unknown windows version'
[[ "$(code "$binary" vm create windows w0 --version=11 --ram=lots --yes)" == 4 ]] || fail 'bad ram'
printf '6\n' > "$tmp/answer"
run env BXCACHY_TTY_IN="$tmp/answer" "$binary" vm create windows --dry-run --json | jq -e '.data.version == "tiny11" and .data.name == "windows" and .data.ram == "7G" and .data.disk == "64G"' >/dev/null || fail "the picker: answer 6 is tiny11, defaults from the machine"
picker_text="$(run env BXCACHY_TTY_IN="$tmp/answer" "$binary" vm create windows --dry-run)"
[[ "$picker_text" == *"Which Windows"* && "$picker_text" == *"UNOFFICIAL"* ]] || fail 'the picker lists the choices'
printf '2022\n' > "$tmp/answer"; run env BXCACHY_TTY_IN="$tmp/answer" "$binary" vm create windows w2022 --dry-run --json | jq -e '.data.version == "2022"' >/dev/null || fail 'the picker takes a version value'
run "$binary" vm create windows --version=11 --ram=6G --cpus=3 --disk=100G --yes --json | jq -e '.ok and .data.name == "windows" and .data.ports.web == 8006 and .data.ports.rdp == 3389' >/dev/null || fail 'create windows'
a="$(args bxcachy-vm-windows)"
for want in "--device /dev/kvm" "--device /dev/net/tun" "--cap-add NET_ADMIN" "--stop-timeout 120" "-p 127.0.0.1:8006:8006" "-p 127.0.0.1:3389:3389/tcp" "-p 127.0.0.1:3389:3389/udp" "-v $tmp/data/vms/windows/storage:/storage" "-v $tmp/home/Windows:/shared" "VERSION=11" "RAM_SIZE=6G" "CPU_CORES=3" "DISK_SIZE=100G" "dockurr/windows"; do [[ "$a" == *"$want"* ]] || fail "windows run args miss '$want': $a"; done
grep -q '^USERNAME=bxcachy$' "$tmp/fake/containers/bxcachy-vm-windows.env" && grep -Eq '^PASSWORD=[0-9a-f]{32}$' "$tmp/fake/containers/bxcachy-vm-windows.env" || fail 'windows env file'
run "$binary" vm create windows w3 --version=10l --share=none --yes >/dev/null; a="$(args bxcachy-vm-w3)"
[[ "$a" == *"-p 127.0.0.1:8007:8006"* && "$a" == *"-p 127.0.0.1:3390:3389/tcp"* && "$a" == *"VERSION=10l"* && "$a" != *":/shared"* ]] || fail "a second Windows gets its own ports: $a"

# list, status, size
run "$binary" vm list --json | jq -e '(.data.vms | length) == 6 and (.data.vms | map(select(.name == "dev")) | .[0] | .state == "running" and .kind == "linux" and .url == "https://127.0.0.1:3001/")' >/dev/null || fail "list: $(run "$binary" vm list --json | jq -c '.data.vms | map(.name)')"
list_text="$(run "$binary" vm list)"; [[ "$list_text" == *"windows "* ]] || fail 'list text'
run "$binary" vm stop dev >/dev/null; run "$binary" vm status dev --json | jq -e '.data.state == "exited"' >/dev/null || fail 'stop and status'
run "$binary" vm start dev >/dev/null; run "$binary" vm status dev --json | jq -e '.data.state == "running"' >/dev/null || fail 'start'
start_text="$(run "$binary" vm start dev)"; [[ "$start_text" == *"already running"* ]] || fail 'start is idempotent'
mkdir -p "$tmp/data/vms/dev/config"; head -c 3000000 /dev/zero > "$tmp/data/vms/dev/config/blob"
run "$binary" vm size dev --json | jq -e '.data.total_kb >= 2900 and (.data.vms | length) == 1' >/dev/null || fail 'size'
size_text="$(run "$binary" vm size)"; [[ "$size_text" == *"Total"* ]] || fail 'size total'
logs_text="$(run "$binary" vm logs dev)"; [[ "$logs_text" == *"log line"* ]] || fail 'logs'
[[ "$(code "$binary" vm status nope)" == 4 && "$(code "$binary" vm start nope)" == 4 ]] || fail 'unknown vm exits 4'

# open
: > "$LOG"; run "$binary" vm open dev >/dev/null; grep -q 'xdg-open https://127.0.0.1:3001/' "$LOG" || fail "open linux: $(cat "$LOG")"
: > "$LOG"; run "$binary" vm open windows --web >/dev/null; grep -q 'xdg-open http://127.0.0.1:8006/' "$LOG" || fail 'open --web'
: > "$LOG"; run "$binary" vm open windows >/dev/null; sleep 0.5
grep -q 'sdl-freerdp3 /args-from:file:' "$LOG" || fail "open windows: $(cat "$LOG")"
f="$tmp/data/vms/windows/rdp.args"
[[ -f "$f" && "$(stat -c %a "$f")" == 600 ]] && grep -q '^/v:127.0.0.1:3389$' "$f" && grep -q '^/u:bxcachy$' "$f" && grep -q '^/p:[0-9a-f]\{32\}$' "$f" && grep -q '^/dynamic-resolution$' "$f" && grep -q '^+clipboard$' "$f" || fail 'the FreeRDP argument file'
! grep -q 'sdl-freerdp3 .*/p:' "$LOG" || fail 'the password must not be on the command line'
run "$binary" vm stop windows >/dev/null; : > "$LOG"; run "$binary" vm open windows >/dev/null; sleep 0.3; run "$binary" vm status windows --json | jq -e '.data.state == "running"' >/dev/null || fail 'open starts a stopped VM'
mv "$tmp/bin/sdl-freerdp3" "$tmp/frdp"; [[ "$(code "$binary" vm open windows)" == 4 ]] || fail 'no FreeRDP client exits 4'; mv "$tmp/frdp" "$tmp/bin/sdl-freerdp3"

# remove
[[ "$(code "$binary" vm remove dev)" == 2 ]] || fail 'remove plan exits 2'
run "$binary" vm remove dev --dry-run --json | jq -e '.dry_run and .data.deletes_data' >/dev/null || fail 'remove dry run'
[[ -d "$tmp/data/vms/dev" ]] || fail 'dry run deleted data'
run "$binary" vm remove arch1 --keep-data --yes >/dev/null; [[ -d "$tmp/data/vms/arch1" && -f "$tmp/cfg/bxcachy/vms/arch1.json" && ! -e "$tmp/fake/containers/bxcachy-vm-arch1.state" ]] || fail '--keep-data keeps data and record, removes the container'
run "$binary" vm remove dev --yes >/dev/null; [[ ! -e "$tmp/data/vms/dev" && ! -e "$tmp/cfg/bxcachy/vms/dev.json" && ! -e "$tmp/fake/containers/bxcachy-vm-dev.state" ]] || fail 'remove deletes the container, data and record'
[[ ! -e "$tmp/data/secrets/BXCACHY_VM_DEV_PASSWORD" ]] || fail 'the stored password is dropped'
[[ -d "$tmp/home/Shared" ]] || fail 'the shared folder is never deleted'

# no engine
[[ "$(set +e; env -i HOME="$tmp/home" BXCACHY_CONFIG_HOME="$tmp/cfg2" BXCACHY_DATA_HOME="$tmp/data2" PATH="/usr/bin:/bin" BXCACHY_VM_SKIP_KVM_CHECK=1 BXCACHY_DRI_DIR="$tmp/dri" "$binary" vm create linux x1 --yes >/dev/null 2>&1; echo $?)" == 4 ]] || fail 'no container engine exits 4'
echo "vm-test: ok"

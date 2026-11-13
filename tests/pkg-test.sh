#!/usr/bin/env bash
# `bxcachy pkg ...` and `bxcachy remove ...` with a stateful fake pacman, yay, sudo, curl (the AUR) and id. Usage: pkg-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/fake/installed"; export LOG="$tmp/log"; : > "$LOG"
# the repo: repo name version description
cat > "$tmp/fake/repo.txt" <<'EOF'
extra ripgrep 15.2.0-1 Search tool that combines grep and ag
extra hyprshot 1.3.0-4 Hyprland screenshot utility
extra jq 1.8.1-1 Command-line JSON processor
core pacman 7.0.0-1 Package manager
EOF
touch "$tmp/fake/installed/hyprshot" "$tmp/fake/installed/pacman" "$tmp/fake/installed/jq"
cat > "$tmp/bin/pacman" <<'FAKE'
#!/usr/bin/env bash
echo "pacman $*" >> "$LOG"
R="$FAKE/repo.txt"; I="$FAKE/installed"
case "$1" in
  -Qq) ls "$I" ;;
  -Qe) for n in $(ls "$I"); do echo "$n 1.0-1"; done ;;
  -Q) for n in $(ls "$I"); do echo "$n 1.0-1"; done ;;
  -Si) awk -v n="$2" '$2==n {print "Repository      : " $1; print "Name            : " $2; print "Version         : " $3; found=1} END {exit found?0:1}' "$R" ;;
  -Ss) q="${@: -1}"; awk -v q="$q" 'index($2,q) || index(tolower($0),q) {m=""; print $1 "/" $2 " " $3 ((system("[ -e '"$I"'/" $2 " ]")==0) ? " [installed]" : ""); d=$0; sub(/^[^ ]+ [^ ]+ [^ ]+ /,"",d); print "    " d; f=1} END {exit f?0:1}' "$R" ;;
  -S) shift; for a in "$@"; do [[ $a == -* ]] || touch "$I/$a"; done ;;
  -Rns) shift; for a in "$@"; do [[ $a == -* ]] || rm -f "${I:?}/${a:?}"; done ;;
esac
FAKE
printf '#!/usr/bin/env bash\necho "sudo $*" >> "$LOG"\nexec "$@"\n' > "$tmp/bin/sudo"
printf '#!/usr/bin/env bash\necho "yay $*" >> "$LOG"\nfor a in "$@"; do [[ $a == -* ]] || touch "$FAKE/installed/$a"; done\n' > "$tmp/bin/yay"
cat > "$tmp/bin/curl" <<'FAKE'
#!/usr/bin/env bash
[[ -n "${AUR_DOWN:-}" ]] && exit 22
url="${@: -1}"
case "$url" in
  */search/*hyprshot*) echo '{"resultcount":2,"results":[{"Name":"hyprshot-git","Version":"1.3.0.r0-1","Description":"screenshots","NumVotes":2,"Popularity":0.1,"OutOfDate":null},{"Name":"hyprshot-gui","Version":"1.5.0-1","Description":"a GUI","NumVotes":9,"Popularity":0.9,"OutOfDate":1700000000}],"type":"search","version":5}' ;;
  */search/*) echo '{"resultcount":0,"results":[],"type":"search","version":5}' ;;
  *info?arg*hyprshot-git*|*info?arg*hyprshot-gui*) echo '{"resultcount":1,"results":[{"Name":"hyprshot-git","Version":"1.3.0-1","Description":"screenshots","Maintainer":"someone","NumVotes":2,"URL":"https://x"}],"type":"multiinfo","version":5}' ;;
  *info*) echo '{"resultcount":0,"results":[],"type":"multiinfo","version":5}' ;;
esac
FAKE
printf '#!/usr/bin/env bash\ncase "$1" in -u) echo "${FAKE_UID:-1000}";; *) echo "${FAKE_UID:-1000}";; esac\n' > "$tmp/bin/id"
chmod +x "$tmp/bin"/*
run() { env HOME="$tmp/home" PATH="$tmp/bin:$PATH" LOG="$LOG" FAKE="$tmp/fake" BXCACHY_AUR_URL="https://aur.test/rpc/v5" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
inst() { [[ -e "$tmp/fake/installed/$1" ]]; }

# search: exact and repo results first, AUR after (by popularity), installed marked, JSON shape
out="$(run "$binary" pkg search hyprshot)"
[[ "$out" == *"* extra/hyprshot 1.3.0-4"* ]] || fail "installed repo package marked: $out"
first="$(printf '%s\n' "$out" | head -1)"; [[ "$first" == *"extra/hyprshot"* ]] || fail "exact name first: $first"
[[ "$out" == *"aur/hyprshot-gui 1.5.0-1 (out of date)"* && "$out" == *"[2 votes]"* ]] || fail "aur rows: $out"
run "$binary" pkg search hyprshot --json | jq -e '.data.total == 3 and (.data.results | map(.source) | .[0] == "repo") and (.data.results | map(select(.name == "hyprshot")) | .[0].installed == true)' >/dev/null || fail "search json: $(run "$binary" pkg search hyprshot --json | head -c 600)"
run "$binary" pkg search ripgrep --source=repo --json | jq -e '.data.total == 1 and .data.results[0].repo == "extra"' >/dev/null || fail 'repo only'
run "$binary" pkg search hyprshot --source=aur --json | jq -e '.data.total == 2 and (.data.results | all(.source == "aur"))' >/dev/null || fail 'aur only'
run "$binary" pkg search hyprshot --limit=1 --json | jq -e '(.data.results | length) == 1 and .data.total == 3' >/dev/null || fail 'limit'
AUR_DOWN=1 run "$binary" pkg search ripgrep --json | jq -e '.ok and (.data.notes | length == 1) and .data.total == 1' >/dev/null || fail 'an AUR outage is a note, repo results stay'
run "$binary" pkg search zzzznothing | grep -q 'No packages match' || fail 'no results'
[[ "$(code "$binary" pkg search 'a;b')" == 2 && "$(code "$binary" pkg search)" == 2 && "$(code "$binary" pkg search x --source=nope)" == 2 ]] || fail 'search validation exits 2'

# info
run "$binary" pkg info ripgrep | grep -q 'Name            : ripgrep' || fail 'repo info'
run "$binary" pkg info hyprshot-git --json | jq -e '.data.source == "aur" and .data.maintainer == "someone"' >/dev/null || fail 'aur info'
[[ "$(code "$binary" pkg info nothing-here)" == 4 ]] || fail 'unknown info exits 4'

# install: a plan until --yes; repo with pacman, AUR with yay; installed ones skipped; unknown exits 4
[[ "$(code "$binary" pkg install ripgrep hyprshot-git)" == 2 ]] || fail 'plan exits 2'
plan="$(run "$binary" pkg install ripgrep hyprshot-git || true)"
[[ "$plan" == *"sudo pacman -S --needed --noconfirm ripgrep"* && "$plan" == *"yay -S --needed --noconfirm hyprshot-git"* && "$plan" == *"yay -G NAME"* ]] || fail "plan text: $plan"
! inst ripgrep || fail 'the plan installed something'
run "$binary" pkg install ripgrep hyprshot-git --dry-run --json | jq -e '.dry_run and (.data.packages | map(.source) == ["repo","aur"])' >/dev/null || fail 'dry run json'
[[ "$(code "$binary" pkg install nope-nope --yes)" == 4 ]] || fail 'unknown package exits 4'
run "$binary" pkg install ripgrep hyprshot-git --yes --json | jq -e '.ok and (.data.done | length == 2)' >/dev/null || fail 'install --yes'
inst ripgrep && inst hyprshot-git || fail 'installed'
grep -q '^yay -S --needed --noconfirm hyprshot-git' "$LOG" || fail 'yay used for the AUR'
run "$binary" pkg install ripgrep --yes | grep -q 'already installed' || fail 'installed ones are skipped'
[[ "$(FAKE_UID=0 code "$binary" pkg install some-aur --aur --yes)" == 4 ]] || fail 'AUR never as root'
run "$binary" pkg installed --explicit --json | jq -e '.data.packages | map(.name) | index("ripgrep") != null' >/dev/null || fail 'installed list'
[[ "$(code "$binary" pkg install)" == 2 && "$(code "$binary" pkg install 'Bad Name')" == 2 ]] || fail 'install validation'
mv "$tmp/bin/yay" "$tmp/yay.off"; rm -f "$tmp/fake/installed/hyprshot-git"
[[ "$(code "$binary" pkg install hyprshot-git --yes)" == 4 ]] || fail 'no yay exits 4'
mv "$tmp/yay.off" "$tmp/bin/yay"

# remove: protected, not installed, plan, real
[[ "$(code "$binary" pkg remove pacman --yes)" == 4 ]] || fail 'protected exits 4'
{ run "$binary" pkg remove linux-cachyos linux-cachyos-nvidia-open --json || true; } | jq -e '.data.blocked | length == 2' >/dev/null || fail 'kernels protected'
run "$binary" pkg remove not-here --yes | grep -q 'not installed' || fail 'not installed is a no-op'
[[ "$(code "$binary" pkg remove ripgrep)" == 2 ]] || fail 'remove plan exits 2'; inst ripgrep || fail 'the plan removed it'
run "$binary" pkg remove ripgrep --dry-run --json | jq -e '.dry_run and .data.command == "sudo pacman -Rns --noconfirm ripgrep"' >/dev/null || fail 'dry run'
run "$binary" pkg remove ripgrep --yes | grep -q 'Removed: ripgrep' || fail 'remove --yes'; ! inst ripgrep || fail 'still installed'
grep -q '^pacman -Rns --noconfirm ripgrep' "$LOG" || fail 'pacman -Rns'

# remove catalog apps: ids map to packages, web apps to launchers, vendor scripts are reported
[[ "$(code "$binary" remove)" == 2 ]] || fail 'remove usage'
run "$binary" remove jq --dry-run --json | jq -e '.data.apps == ["jq"] and .data.remove == ["jq"]' >/dev/null || fail 'a catalog id maps to its package'
run "$binary" remove jq --yes >/dev/null; ! inst jq || fail 'catalog app removed'
webid="$(cd "$(dirname "$binary")/.." && jq -r '[.apps[] | select(.source == "web")][0].id' catalog/apps.json)"
mkdir -p "$tmp/home/.local/share/applications"; echo x > "$tmp/home/.local/share/applications/bxcachy-$webid.desktop"
run "$binary" remove "$webid" --dry-run --json | jq -e --arg id "$webid" '.data.launchers | length == 1' >/dev/null || fail 'web launcher found'
run "$binary" remove "$webid" --yes | grep -q "Removed web app: $webid" || fail 'web launcher removed'
[[ ! -e "$tmp/home/.local/share/applications/bxcachy-$webid.desktop" ]] || fail 'launcher still there'
run "$binary" remove "$webid" --yes | grep -q 'Nothing to do' || fail 'a removed web app is a no-op'
scriptid="$(cd "$(dirname "$binary")/.." && jq -r '[.apps[] | select(.source == "script")][0].id' catalog/apps.json)"
run "$binary" remove "$scriptid" --json | jq -e '.exit == 4 and (.data.manual | length == 1)' >/dev/null || { [[ "$(code "$binary" remove "$scriptid")" == 4 ]] || fail 'vendor-script apps are reported, not guessed'; }
echo "pkg-test: ok"

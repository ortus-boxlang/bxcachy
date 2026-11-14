#!/usr/bin/env bash
# The Apps manager page (`bxrig tui apps`) on a fake machine: fake pacman, checkupdates, flatpak, desktop files. Usage: apps-manager-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/desk" "$tmp/cache"
d() { printf '[Desktop Entry]\n%s\n' "$2" > "$1"; }
d "$tmp/desk/firefox.desktop" $'Type=Application\nName=Firefox\nComment=Web browser\nExec=firefox %u\nIcon=firefox'
d "$tmp/desk/thunderbird.desktop" $'Type=Application\nName=Thunderbird\nExec=thunderbird %u\nIcon=thunderbird'
d "$tmp/desk/code.desktop" $'Type=Application\nName=Visual Studio Code\nExec=code %F\nIcon=code'
d "$tmp/desk/strata.desktop" $'Type=Application\nName=Strata\nExec=strata\nIcon=strata'
d "$tmp/desk/firefox-private.desktop" $'Type=Application\nName=Firefox Private\nExec=firefox --private-window\nIcon=firefox'
d "$tmp/desk/hidden.desktop" $'Type=Application\nName=Hidden thing\nExec=hidden\nNoDisplay=true'
d "$tmp/desk/orphan.desktop" $'Type=Application\nName=Orphan\nExec=orphan'
# fake pacman: every call is logged
cat > "$tmp/bin/pacman" <<'PACMAN'
#!/usr/bin/env bash
echo "$*" >> "$FAKE/pacman.log"
case "$1" in
  -Qo) shift; for f in "$@"; do case "$f" in
        */firefox.desktop|*/firefox-private.desktop) echo "$f is owned by firefox 133.0-1" ;;
        */thunderbird.desktop) echo "$f is owned by thunderbird 128.5.0-1" ;;
        */code.desktop) echo "$f is owned by visual-studio-code-bin 1.95.3-1" ;;
        */strata.desktop) echo "$f is owned by strata 0.9.2-1" ;;
        *) echo "error: No package owns $f" >&2 ;; esac; done ;;
  -Qm) echo "visual-studio-code-bin 1.95.3-1" ;;
  -Qq) printf 'firefox\nthunderbird\nvisual-studio-code-bin\nstrata\nbash\n' ;;
  -Q) printf 'firefox 133.0-1\nbash 5.2-1\n' ;;
  -Sl) printf 'extra firefox 133.0-1 [installed]\nextra thunderbird 128.5.0-1 [installed]\nextra evolution 3.54-1\n' ;;
  -Qi) shift; for p in "$@"; do printf 'Name            : %s\nVersion         : 1.0-1\nDescription     : The %s package\nURL             : https://example.org/%s\nDepends On      : glibc  gtk3\nRequired By     : None\nInstalled Size  : 100.00 MiB\nInstall Date    : Mon 02 Oct 2026\n\n' "$p" "$p" "$p"; done ;;
  -Si) printf 'Name            : %s\nVersion         : 2.0-1\nDescription     : Repo package\nDepends On      : None\nRequired By     : None\nInstalled Size  : 5.00 MiB\n\n' "$2" ;;
  -Rns) printf 'strata\nlibstrata\n' ;;
  *) exit 1 ;;
esac
PACMAN
printf '#!/usr/bin/env bash\necho "checkupdates $*" >> "$FAKE/pacman.log"\nprintf "firefox 133.0-1 -> 133.0.3-1\\nbash 5.2-1 -> 5.3-1\\n"\n' > "$tmp/bin/checkupdates"
printf '#!/usr/bin/env bash\nprintf "org.gimp.GIMP\\tGIMP\\t3.0.0\\t310.0 MB\\n"\n' > "$tmp/bin/flatpak"
chmod +x "$tmp/bin"/*
export FAKE="$tmp"
run() { env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_STATE_HOME="$tmp/state" BXRIG_CACHE_HOME="$tmp/cache" BXRIG_DESKTOP_DIRS="$tmp/desk" BXRIG_SELF="$binary" FAKE="$tmp" PATH="$tmp/bin:$PATH" "$@"; }

# installed: the apps with a launcher, one row per package, sources named in words, one batched `pacman -Qo`
out="$(run "$binary" tui apps --json)"
echo "$out" | jq -e '.ok and .data.tab == "installed" and .data.focus == "search"' >/dev/null || fail "page json: $out"
echo "$out" | jq -e '[.data.rows[].name] == ["Firefox","GIMP","Orphan","Strata","Thunderbird","Visual Studio Code"]' >/dev/null || fail "installed names (one row per package, hidden ones dropped, Flatpak included): $(echo "$out" | jq -c '[.data.rows[].name]')"
echo "$out" | jq -e '(.data.rows | map(select(.name == "Visual Studio Code"))[0].source) == "AUR" and (.data.rows | map(select(.name == "Firefox"))[0].source) == "extra" and (.data.rows | map(select(.name == "GIMP"))[0].source) == "Flatpak" and (.data.rows | map(select(.name == "Orphan"))[0].source) == "built here"' >/dev/null || fail "sources: $(echo "$out" | jq -c '[.data.rows[] | {name,source}]')"
echo "$out" | jq -e '(.data.rows | map(select(.name == "Firefox"))[0].size) == 104857600 and (.data.rows | map(select(.name == "Firefox"))[0].since) == "Mon 02 Oct 2026"' >/dev/null || fail 'size and date from pacman -Qi'
[[ "$(grep -c '^-Qo ' "$tmp/pacman.log")" == 1 ]] || fail "pacman -Qo is called once for all desktop files ($(grep -c '^-Qo ' "$tmp/pacman.log"))"
# updates: counted from checkupdates, shown on the tab
echo "$out" | jq -e '.data.counts.updates == 2 and .data.updatesDone == true' >/dev/null || fail "updates count: $(echo "$out" | jq -c '.data.counts')"
echo "$out" | jq -e '.data.counts.installed == 6' >/dev/null || fail 'installed count'

# no pacman and no apps: a sentence, not a crash
mkdir -p "$tmp/emptybin"; for t in sh jq sed mv rm mkdir cat nohup; do ln -s "$(command -v $t)" "$tmp/emptybin/$t"; done
out2="$(env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_CACHE_HOME="$tmp/cache2" BXRIG_DESKTOP_DIRS="$tmp/none" BXRIG_SELF="$binary" PATH="$tmp/emptybin" "$binary" tui apps --json || true)"
echo "$out2" | jq -e '.ok and .data.counts.installed == 0' >/dev/null || fail "no apps and no pacman: $out2"

# demo data: eight apps, three updates
"$binary" tui apps --demo --json | jq -e '.data.counts.installed == 8 and .data.counts.updates == 3' >/dev/null || fail 'demo counts'

# the page is listed with the others, right after the dashboard
"$binary" tui list --json | jq -e '[.data.pages[].id] | index("apps") == 1' >/dev/null || fail 'tui list has apps right after dashboard'
echo "apps-manager-test: ok"

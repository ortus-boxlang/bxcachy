#!/usr/bin/env bash
# `bxcachy db` end to end with a fake, stateful podman/docker (no containers are started). Usage: db-test.sh BINARY
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/fake"
# fake container engine: keeps one folder per container, logs every call to $FAKE/<program>.log
cat > "$tmp/bin/fakeengine" <<'FAKE'
#!/usr/bin/env bash
prog="$(basename "$0")"; db="$FAKE/containers"; mkdir -p "$db"
echo "$*" >> "$FAKE/$prog.log"
case "$1" in
  --version) echo "$prog version 5.0" ;;
  container)  # container inspect [--format F] NAME
    name="${@: -1}"; [[ -d "$db/$name" ]] || exit 1
    if [[ "$3" == --format ]]; then cat "$db/$name/state"; fi ;;
  run) [[ -z "${FAKE_FAIL:-}" ]] || { echo "boom: image pull failed"; exit 125; }
    name=""; for ((i=1;i<=$#;i++)); do [[ "${!i}" == --name ]] && { j=$((i+1)); name="${!j}"; }; done
    mkdir -p "$db/$name"; echo running > "$db/$name/state"; echo "$*" > "$db/$name/run"; echo "abc123" ;;
  start) echo running > "$db/$2/state" ;;
  stop) echo exited > "$db/$2/state" ;;
  rm) rm -rf "$db/${@: -1}" ;;
  volume) : ;;
  logs) echo "log line from ${@: -1}" ;;
  ps) for d in "$db"/*/; do [[ -d "$d" ]] && echo "$(basename "$d")|Up 2 minutes|image"; done ;;
  *) exit 9 ;;
esac
FAKE
chmod +x "$tmp/bin/fakeengine"; ln -s fakeengine "$tmp/bin/podman"; ln -s fakeengine "$tmp/bin/docker"
export FAKE="$tmp/fake"
run() { env BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_DATA_HOME="$tmp/data" HOME="$tmp/home" PATH="$tmp/bin:$PATH" FAKE="$FAKE" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
c=bxcachy-db

# the registry
[[ "$(run "$binary" db engines --json | jq '.data.engines | length')" == 14 ]] || fail '14 engines'
run "$binary" db engines --json | jq -e '[.data.engines[].id] | (index("meilisearch") and index("opensearch") and index("elasticsearch") and index("couchbase") and index("mongodb"))' >/dev/null || fail 'search engines, Couchbase and MongoDB are there'
run "$binary" db engines --json | jq -e '.data.engines | map(select(.id=="milvus"))[0].supported == false' >/dev/null || fail 'Milvus is listed as unsupported'

# bad input
[[ "$(code "$binary" db start milvus --yes)" == 4 ]] || fail 'Milvus exits 4'
[[ "$(code "$binary" db start nope --yes)" == 2 ]] || fail 'an unknown engine exits 2'
[[ "$(code "$binary" db start postgres --name='bad name' --yes)" == 4 ]] || fail 'a bad name exits 4'
[[ "$(code "$binary" db start postgres --port=80 --yes)" == 4 && "$(code "$binary" db start postgres --port=abc --yes)" == 4 ]] || fail 'a bad port exits 4'
[[ "$(code "$binary" db start couchbase --port=9000 --yes)" == 4 ]] || fail 'Couchbase has fixed ports'
[[ "$(code "$binary" db)" == 2 && "$(code "$binary" db bogus)" == 2 && "$(code "$binary" db start)" == 2 ]] || fail 'usage exits 2'
env BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_DATA_HOME="$tmp/data" HOME="$tmp/home" PATH="/usr/bin:/bin" "$binary" db start postgres --yes >/dev/null 2>&1 && fail 'no container engine must fail'
[[ "$(env BXCACHY_CONFIG_HOME="$tmp/cfg" BXCACHY_DATA_HOME="$tmp/data" HOME="$tmp/home" PATH="/usr/bin:/bin" "$binary" db start postgres --yes >/dev/null 2>&1; echo $?)" == 4 ]] || fail 'no container engine exits 4'

# plan and dry-run create nothing
[[ "$(code "$binary" db start postgres)" == 2 ]] || fail 'no --yes exits 2'
run "$binary" db start postgres --dry-run --json | jq -e '.ok and .dry_run and (.data.would | contains("create bxcachy-db-postgres-default"))' >/dev/null || fail 'dry-run --json'
[[ ! -d "$tmp/fake/containers" || -z "$(ls "$tmp/fake/containers" 2>/dev/null)" ]] || fail 'the plan created a container'
[[ ! -e "$tmp/data" ]] || fail 'the plan wrote files'

# start PostgreSQL
run "$binary" db start postgres --yes --json | jq -e '.ok and .data.port == 5432 and .data.listens == "127.0.0.1"' >/dev/null || fail 'start postgres'
runline="$(cat "$FAKE/containers/$c-postgres-default/run")"
for want in "--name $c-postgres-default" '--label io.bxcachy.database=true' '--label io.bxcachy.engine=postgres' '--restart unless-stopped' '-p 127.0.0.1:5432:5432' "-v $c-postgres-default:/var/lib/postgresql/data" '--env-file ' ' docker.io/library/postgres:17'; do [[ "$runline" == *"$want"* ]] || fail "run line lacks [$want]: $runline"; done
dir="$tmp/data/databases/$c-postgres-default"
[[ "$(stat -c %a "$dir/password")" == 600 && "$(stat -c %a "$dir/database.env")" == 600 ]] || fail 'password files must be mode 600'
pw="$(tr -d '\n' < "$dir/password")"; [[ ${#pw} -ge 48 ]] || fail 'the password is long and random'
[[ "$(cat "$dir/database.env")" == "POSTGRES_PASSWORD=$pw" ]] || fail 'the env file holds the password'
[[ "$runline" != *"$pw"* ]] || fail 'the password must never be on a command line'

# a second start never replaces the container
before="$(wc -l < "$FAKE/podman.log")"
run "$binary" db start postgres --yes --json | jq -e '.ok and .data.already == "running"' >/dev/null || fail 'a running container is left alone'
! tail -n +$((before+1)) "$FAKE/podman.log" | grep -q '^run ' || fail 'a second start must not run a new container'

# stop, status, start the stopped one (start, not run)
run "$binary" db stop postgres | grep -q "Stopped $c-postgres-default" || fail 'stop'
run "$binary" db status postgres --json | jq -e '.data.status == "exited"' >/dev/null || fail 'status'
before="$(wc -l < "$FAKE/podman.log")"
run "$binary" db start postgres --yes | grep -q "Started $c-postgres-default" || fail 'start a stopped container'
tail -n +$((before+1)) "$FAKE/podman.log" | grep -q "^start $c-postgres-default" && ! tail -n +$((before+1)) "$FAKE/podman.log" | grep -q '^run ' || fail 'a stopped container is started, not recreated'
run "$binary" db logs postgres | grep -q "log line from $c-postgres-default" || fail 'logs'
[[ "$(code "$binary" db status mysql)" == 4 ]] || fail 'status of a missing container exits 4'

# info hides the password unless asked
out="$(run "$binary" db info postgres)"; [[ "$out" == *'postgresql://postgres:********@127.0.0.1:5432/postgres'* && "$out" != *"$pw"* ]] || fail "info masks the password: $out"
run "$binary" db info postgres --show-password | grep -q "postgresql://postgres:$pw@127.0.0.1:5432/postgres" || fail 'info --show-password'
run "$binary" db info postgres --json | jq -e '.data.host == "127.0.0.1" and .data.port == 5432 and (.data.url | contains("********")) and .data.password_file != ""' >/dev/null || fail 'info --json'
[[ "$(code "$binary" db info mysql)" == 4 ]] || fail 'info for an unknown instance exits 4'

# another name and port, side by side
run "$binary" db start postgres --name=app --port=5433 --yes >/dev/null || fail 'second instance'
grep -q -- '-p 127.0.0.1:5433:5432' "$FAKE/containers/$c-postgres-app/run" || fail 'custom host port'
run "$binary" db list | grep -q "$c-postgres-app" || fail 'list shows both'

# engines with other shapes
run "$binary" db start redis --yes >/dev/null || fail 'redis'
r="$(cat "$FAKE/containers/$c-redis-default/run")"; [[ "$r" == *' docker.io/library/redis:7.4 redis-server --appendonly yes' && "$r" != *'--env-file'* ]] || fail "redis: $r"
run "$binary" db start mongodb --yes >/dev/null || fail 'mongodb'; grep -q 'MONGO_INITDB_ROOT_USERNAME=root' "$FAKE/containers/$c-mongodb-default/run" || fail 'mongodb root user'
run "$binary" db start meilisearch --yes >/dev/null || fail 'meilisearch'; grep -q 'MEILI_ENV=production' "$FAKE/containers/$c-meilisearch-default/run" && grep -q '^MEILI_MASTER_KEY=' "$tmp/data/databases/$c-meilisearch-default/database.env" || fail 'meilisearch production mode with a master key'
run "$binary" db start couchbase --yes >/dev/null || fail 'couchbase'; r="$(cat "$FAKE/containers/$c-couchbase-default/run")"; [[ "$r" == *'-p 127.0.0.1:8091:8091'* && "$r" == *'-p 127.0.0.1:11210:11210'* ]] || fail 'couchbase ports'
run "$binary" db info couchbase | grep -q 'http://127.0.0.1:8091' || fail 'couchbase info documents the web setup'

# OpenSearch and Elasticsearch need vm.max_map_count; the generated OpenSearch password meets its policy
echo 65530 > "$tmp/mmc"
[[ "$(BXCACHY_MAX_MAP_COUNT_FILE="$tmp/mmc" code "$binary" db start opensearch --yes)" == 4 && "$(BXCACHY_MAX_MAP_COUNT_FILE="$tmp/mmc" code "$binary" db start elasticsearch --yes)" == 4 ]] || fail 'a low vm.max_map_count exits 4'
out="$(BXCACHY_MAX_MAP_COUNT_FILE="$tmp/mmc" run "$binary" db start opensearch --yes 2>&1 || true)"; [[ "$out" == *'sudo sysctl -w vm.max_map_count=262144'* ]] || fail 'the fix is named'
echo 262144 > "$tmp/mmc"
BXCACHY_MAX_MAP_COUNT_FILE="$tmp/mmc" run "$binary" db start opensearch --yes >/dev/null || fail 'opensearch'
grep -q 'discovery.type=single-node' "$FAKE/containers/$c-opensearch-default/run" || fail 'opensearch single node'
ospw="$(tr -d '\n' < "$tmp/data/databases/$c-opensearch-default/password")"; [[ "$ospw" =~ [A-Z] && "$ospw" =~ [a-z] && "$ospw" =~ [0-9] && "$ospw" =~ [^A-Za-z0-9] && ${#ospw} -ge 8 ]] || fail 'the OpenSearch password meets its policy'
grep -q '^OPENSEARCH_INITIAL_ADMIN_PASSWORD=' "$tmp/data/databases/$c-opensearch-default/database.env" || fail 'opensearch admin password env'
BXCACHY_MAX_MAP_COUNT_FILE="$tmp/mmc" run "$binary" db start elasticsearch --yes >/dev/null || fail 'elasticsearch'
grep -q 'elasticsearch/elasticsearch:9.5.6' "$FAKE/containers/$c-elasticsearch-default/run" && grep -q '^ELASTIC_PASSWORD=' "$tmp/data/databases/$c-elasticsearch-default/database.env" || fail 'elasticsearch'

# remove keeps the data; --delete-data removes it
[[ "$(code "$binary" db remove postgres)" == 2 ]] || fail 'remove without --yes exits 2'
run "$binary" db remove postgres --delete-data --dry-run | grep -q 'AND delete its data' || fail 'the plan says what --delete-data does'
run "$binary" db remove postgres --yes | grep -q 'were kept' || fail 'remove'
[[ ! -d "$FAKE/containers/$c-postgres-default" && -f "$dir/password" ]] || fail 'remove keeps the password file (and the data volume)'
! grep -q '^volume rm' "$FAKE/podman.log" || fail 'plain remove must not delete a volume'
run "$binary" db remove postgres --delete-data --yes >/dev/null || fail 'remove --delete-data'
grep -q "^volume rm $c-postgres-default" "$FAKE/podman.log" && [[ ! -d "$dir" ]] || fail '--delete-data removes the volume and the files'

# a failing container command: exit 6 and no leftovers
rc=0; FAKE_FAIL=1 run "$binary" db start qdrant --yes >/dev/null 2>&1 || rc=$?
[[ "$rc" == 6 && ! -d "$tmp/data/databases/$c-qdrant-default" ]] || fail "a failed run exits 6 and cleans up (rc=$rc)"

# Docker instead of Podman
[[ "$(run "$binary" db engine)" == 'Container engine: podman' ]] || fail 'podman is the default'
[[ "$(code "$binary" db engine rkt)" == 2 ]] || fail 'an unknown engine choice exits 2'
run "$binary" db engine docker >/dev/null; [[ "$(run "$binary" db engine)" == 'Container engine: docker' ]] || fail 'engine docker is saved'
run "$binary" db start chroma --yes >/dev/null || fail 'chroma on docker'
grep -q '^run .*chromadb/chroma:1.5.9' "$FAKE/docker.log" && ! grep -q 'chroma' "$FAKE/podman.log" || fail 'the chosen engine ran the container'
# the control center: choices come from the runner's menu provider (a fake Rofi plays the answers), results open in a terminal
rm -rf "$tmp/fake"; mkdir -p "$tmp/fake" "$tmp/bin2"
printf '#!/usr/bin/env bash\ncat > /dev/null\nn=$(( $(cat "$FAKE/n" 2>/dev/null || echo 0) + 1 )); echo $n > "$FAKE/n"\nsed -n "${n}p" "$FAKE/answers"\n' > "$tmp/bin/rofi"
printf '#!/usr/bin/env bash\necho "terminal $*" >> "$FAKE/terminal.log"\n' > "$tmp/bin/ghostty"; chmod +x "$tmp/bin/rofi" "$tmp/bin/ghostty"
run "$binary" runner menu-set rofi >/dev/null
# 0 = PostgreSQL, 0 = Start, 1 = Confirm, then 13 = Exit (13 engines are supported, Exit is the 14th entry)
printf '0\n0\n1\n13\n' > "$FAKE/answers"
BXCACHY_SELF=/opt/bxcachy run "$binary" db menu || fail 'db menu exits 0'
for _ in 1 2 3 4 5 6 7 8 9 10; do [[ -s "$FAKE/terminal.log" ]] && break; sleep 0.3; done
grep -q 'terminal -e sh -c .* _ /opt/bxcachy db start postgres --yes' "$FAKE/terminal.log" || fail "the menu starts PostgreSQL in a terminal: $(cat "$FAKE/terminal.log" 2>/dev/null)"
# cancelling the confirmation runs nothing; picking Cancel (0) on the confirm step
rm -f "$FAKE/n" "$FAKE/terminal.log"; printf '3\n5\n0\n13\n' > "$FAKE/answers"
run "$binary" db menu || fail 'db menu (cancel)'; sleep 0.5
[[ ! -s "$FAKE/terminal.log" ]] || fail 'a cancelled confirmation must not run anything'
# a menu program that is missing is an error, not a hang
rm "$tmp/bin/rofi"; [[ "$(code "$binary" db menu)" == 4 ]] || fail 'a missing menu program exits 4'
echo "db tests passed"

#!/usr/bin/env bash
# Runs the migrations and the SQL tests on a throwaway local Postgres.
#   supabase/tests/run.sh                 starts its own cluster (needs Postgres server binaries)
#   PGURL=postgres://... run.sh           uses an existing empty database instead
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$here/.."

if [ -z "${PGURL:-}" ]; then
  bin=$(ls -d /usr/lib/postgresql/*/bin | sort -V | tail -1)
  dir=$(mktemp -d)
  chmod 777 "$dir"
  as_pg() { if [ "$(id -u)" = 0 ]; then runuser -u postgres -- "$@"; else "$@"; fi; }
  as_pg "$bin/initdb" -D "$dir/data" -A trust >/dev/null
  as_pg "$bin/pg_ctl" -D "$dir/data" -o "-p 54399 -k $dir -c listen_addresses=''" -l "$dir/log" -w start >/dev/null
  trap 'as_pg "$bin/pg_ctl" -D "$dir/data" -m immediate stop >/dev/null 2>&1; rm -rf "$dir"' EXIT
  PGURL="postgresql://postgres@/postgres?host=$dir&port=54399"
fi

psql_run() { psql "$PGURL" -v ON_ERROR_STOP=1 -q "$@"; }

echo "== setup_all.sql matches the migrations"
"$root/../tool/build_setup_sql.sh" --check

echo "== shim"
psql_run -f "$here/shim.sql" >/dev/null
echo "== setup_all.sql (what you paste into the dashboard)"
psql_run -f "$root/setup_all.sql" >/dev/null
echo "== tests"
for f in "$here"/*_test.sql; do
  echo "-- $(basename "$f")"
  psql_run -o /dev/null -f "$f" 2>&1 | sed -E 's/^psql:[^ ]+ (NOTICE|ERROR): +//' | grep -vE "^(CONTEXT|$)"
  [ "${PIPESTATUS[0]}" = 0 ] || { echo "SQL tests FAILED"; exit 1; }
done
echo "== seed"
psql_run -f "$root/seed.sql" >/dev/null
psql_run -t -A -c "select 'seeded: ' || count(*) || ' bills, open tab total ' || coalesce(sum(owed_amount),0) from bills, settlements where bills.id = settlements.bill_id" | head -1
echo "all sql tests passed"
